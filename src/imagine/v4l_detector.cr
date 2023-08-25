require "./model_adaptor"
require "stumpy_core"
require "ffmpeg"
require "./fps"
require "v4l2"

class Imagine::V4L2Detector
  alias Detection = TensorflowLite::Image::ObjectDetection::Detection
  alias Canvas = StumpyCore::Canvas

  def initialize(@input : Path, @format : V4L2::FrameRate, model : ModelAdaptor)
    # ai detection invoker
    @model = model
    @ai_invoke = Tasker::Pipeline(Canvas, Tuple(Canvas, Array(Detection))).new("model invocation") do |canvas|
      model.process(canvas)
    end
  end

  # video and NN model processing
  getter input : Path
  getter format : V4L2::FrameRate
  @video : V4L2::Video? = nil
  getter model : ModelAdaptor
  getter ai_invoke : Tasker::Pipeline(Canvas, Tuple(Canvas, Array(Detection)))

  # how many detections are running
  getter fps : FPS = FPS.new
  @next_fps_window : FPS = FPS.new

  # State of detector, stream might not always be available
  getter? processing : Bool = false
  getter last_error : Exception? = nil

  def detections(&detection : (Canvas, Array(Detection), FPS, Time::Span) -> Nil)
    return if @processing
    @processing = true

    @fps = FPS.new
    @next_fps_window = FPS.new

    # start processing video based on the model requirements
    spawn { process_video }
    spawn { track_fps }

    # yield any detections
    @ai_invoke.subscribe do |(canvas, detections)|
      if @fps.operations.zero?
        @fps.reset
        @next_fps_window.reset
      end

      @fps.increment
      @next_fps_window.increment
      detection.call(canvas, detections, @fps, @ai_invoke.time) unless detections.empty?
    end
  end

  def stop
    @processing = false
    @ai_invoke.close
    @video.try &.stop_stream
  end

  protected def process_video : Nil
    pipeline = @ai_invoke
    format = @format

    # calculate the resolutions and processing requirements
    desired_width, desired_height = model.input_resolution
    output_width, output_height = FFmpeg::Video.scale_to_fit(format.width.to_i, format.height.to_i, desired_width, desired_height)
    requires_cropping = desired_width != output_width || desired_height != output_height

    # configure the data structures
    rgb_frame = FFmpeg::Frame.new(output_width, output_height, :rgb48Le)
    scaler = FFmpeg::SWScale.new(format.width, format.height, :yuyv422, output_width, output_height, :rgb48Le)
    canvas = StumpyCore::Canvas.new(output_width, output_height)
    cropped = StumpyCore::Canvas.new(desired_width, desired_height)

    # create a view into the frame buffer for simplified data extraction
    # works on the assumption that the code is running on a LE system
    pixel_components = output_width * output_height * 3
    pointer = Pointer(UInt16).new(rgb_frame.buffer.to_unsafe.address)
    frame_buffer = Slice.new(pointer, pixel_components)

    # configure device
    video = V4L2::Video.new(@device)
    video.set_format(format).request_buffers(1)

    # grab the frames
    video.stream do |buffer|
      if pipeline.idle?
        v4l2_frame = FFmpeg::Frame.new(format.width, format.height, :yuyv422, buffer: buffer)
        convert.scale(v4l2_frame, rgb_frame)

        # copy frame into a stumpy canvas
        canvas.pixels.size.times do |index|
          idx = index * 3
          r = frame_buffer[idx]
          g = frame_buffer[idx + 1]
          b = frame_buffer[idx + 2]
          canvas.pixels[index] = StumpyCore::RGBA.new(r, g, b)
        end

        # finalise the image for AI processing
        output = requires_cropping ? FFmpeg::Video.crop(canvas, cropped) : canvas
        pipeline.process output
      end
    end
  rescue error
    # stream probably not online, we'll just keep retrying
    Log.trace(exception: error) { "error extracting frame" }
    @last_error = error
    sleep 0.2
    spawn { process_video } if @processing
  end

  protected def track_fps
    loop do
      sleep 5
      break unless @processing
      @fps = @next_fps_window
      @next_fps_window = FPS.new
    end
  end
end
