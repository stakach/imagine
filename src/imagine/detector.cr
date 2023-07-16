require "./model_adaptor"
require "stumpy_core"
require "ffmpeg"
require "./fps"

class Imagine::Detector
  alias Detection = TensorflowLite::Image::ObjectDetection::Detection
  alias Canvas = StumpyCore::Canvas
  alias Keyframe = Bool

  def initialize(@input : URI | Path, model : ModelAdaptor)
    # ai detection invoker
    @model = model
    @ai_invoke = Tasker::Pipeline(Tuple(Canvas, Keyframe), Tuple(Canvas, Array(Detection))).new("model invocation") do |(canvas, _keyframe)|
      model.process(canvas)
    end
  end

  # video and NN model processing
  getter input : URI | Path
  @video : FFmpeg::Video? = nil
  getter model : ModelAdaptor
  getter ai_invoke : Tasker::Pipeline(Tuple(Canvas, Keyframe), Tuple(Canvas, Array(Detection)))

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
    @video.try &.close
  end

  protected def process_video : Nil
    # we capture as fast as we can, we just skip running detections if they cant keep up
    @video = video = FFmpeg::Video.open(@input)
    required_width, required_height = model.input_resolution
    video.frame_pipeline(@ai_invoke, required_width, required_height)
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
