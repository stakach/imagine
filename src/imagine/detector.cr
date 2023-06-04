require "./model_adaptor"
require "./processor"
require "stumpy_core"
require "ffmpeg"
require "./fps"

class Imagine::Detector
  alias Detection = TensorflowLite::Image::ObjectDetection::Detection
  alias Canvas = StumpyCore::Canvas

  def initialize(@input : URI | Path, model : ModelAdaptor)
    # scaling
    input_width, input_height = model.input_resolution
    @scaler = Processor(Canvas, Canvas).new("image scaling") do |canvas|
      StumpyResize.scale_to_cover(canvas, input_width, input_height, :nearest_neighbor)
    end

    # ai detection invoker
    @model = model
    @ai_invoke = Processor(Canvas, Tuple(Canvas, Array(Detection))).new("model invocation") do |canvas|
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

  @scaler : Processor(Canvas, Canvas)
  @ai_invoke : Processor(Canvas, Tuple(Canvas, Array(Detection)))

  # how many detections are running
  getter fps : FPS = FPS.new
  @next_fps_window : FPS = FPS.new

  # State of detector, stream might not always be available
  getter? processing : Bool = false
  getter last_error : Exception? = nil

  def detections
    return if @processing
    @processing = true

    @fps = FPS.new
    @next_fps_window = FPS.new

    # start processing video based on the model requirements
    spawn { process_video }
    spawn { track_fps }

    # yield any detections
    while @processing
      if @fps.operations.zero?
        @fps.reset
        @next_fps_window.reset
      end

      canvas, detections = @ai_invoke.receive

      @fps.increment
      @next_fps_window.increment
      yield(canvas, detections, @fps) unless detections.empty?
    end
  ensure
    stop
  end

  def stop
    @scaler.stop
    @ai_invoke.stop
    @processing = false
  end

  protected def process_video : Nil
    # we capture as fast as we can, we just skip running detections if they cant keep up
    @video = video = FFmpeg::Video.open(@input)
    video.each_frame do |canvas, _key_frame|
      @scaler.process canvas
      break unless @processing
    end
  rescue error
    # stream probably not online, we'll just keep retrying
    Log.trace(exception: error) { "error extracting frame" }
    @last_error = error
    sleep 0.2
    spawn { process_video }
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
