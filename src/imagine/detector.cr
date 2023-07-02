require "./model_adaptor"
require "./processor"
require "stumpy_core"
require "ffmpeg"
require "./fps"

class Imagine::Detector
  alias Detection = TensorflowLite::Image::ObjectDetection::Detection
  alias Canvas = StumpyCore::Canvas

  def initialize(@input : URI | Path, model : ModelAdaptor)
    # are we ready to receive a frame
    @next_frame = Channel(Nil).new(1)

    # scaling
    # TODO:: if no scaling required then we need to dup input canvas
    # as the input canvas is reused once we signal for the next frame
    input_width, input_height = model.input_resolution
    @scaler = Processor(Canvas, Canvas).new("image scaling") do |canvas|
      output = StumpyResize.scale_to_cover(canvas, input_width, input_height, :nearest_neighbor)
      @next_frame.send nil
      output
    end

    # ai detection invoker
    @model = model
    @ai_invoke = Processor(Canvas, Tuple(Canvas, Array(Detection))).new("model invocation", 1) do |canvas|
      model.process(canvas)
    end

    # pipe scaling into the detector
    # no blocking, we want a detection to be as close
    # to real-time as possible so anything we act on
    # is as valid as possible
    spawn do
      loop do
        scaled = @scaler.receive?
        break unless scaled
        @ai_invoke.process scaled
      end
    end
  end

  # video and NN model processing
  getter input : URI | Path
  @video : FFmpeg::Video? = nil
  getter model : ModelAdaptor

  getter scaler : Processor(Canvas, Canvas)
  getter ai_invoke : Processor(Canvas, Tuple(Canvas, Array(Detection)))

  # how many detections are running
  getter fps : FPS = FPS.new
  @next_fps_window : FPS = FPS.new

  # State of detector, stream might not always be available
  getter? processing : Bool = false
  getter last_error : Exception? = nil

  getter frame_counter : UInt64 = 0
  getter frame_invoked : UInt64 = 0

  def detections(&)
    return if @processing
    @processing = true

    @fps = FPS.new
    @next_fps_window = FPS.new

    # start processing video based on the model requirements
    spawn { process_video }
    spawn { track_fps }
    @next_frame = Channel(Nil).new(1)
    @next_frame.send nil

    # yield any detections
    while @processing
      if @fps.operations.zero?
        @fps.reset
        @next_fps_window.reset
      end

      canvas, detections = @ai_invoke.receive

      @fps.increment
      @next_fps_window.increment
      yield(canvas, detections, @fps, @scaler.time, @ai_invoke.time, @frame_counter, @frame_invoked) unless detections.empty?
    end
  ensure
    stop
  end

  def stop
    @scaler.stop
    @ai_invoke.stop
    @next_frame.close
    @processing = false
  end

  protected def process_video : Nil
    data = Channel(Tuple(StumpyCore::Canvas, Bool)).new(1)

    begin
      # we capture as fast as we can, we just skip running detections if they cant keep up
      @video = video = FFmpeg::Video.open(@input)
      spawn { video.async_frames(@next_frame, data) }

      loop do
        frame, _key_frame = data.receive
        @frame_counter += 1
        @frame_invoked += 1 if @scaler.process frame
        break unless @processing
      end
    rescue error
      # stream probably not online, we'll just keep retrying
      Log.trace(exception: error) { "error extracting frame" }
      @last_error = error
      sleep 0.2
      spawn { process_video }
    ensure
      data.close
    end
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
