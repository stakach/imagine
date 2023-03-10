require "./model_adaptor"
require "stumpy_core"
require "ffmpeg"
require "./fps"

class Imagine::Detector
  def initialize(@input : URI | Path, @model : ModelAdaptor)
  end

  # State of detector, stream might not always be available
  @state_mutex : Mutex = Mutex.new
  @processing_count : Int32 = 0
  @performing_detection : Bool = false
  getter? processing : Bool = false
  getter? error : Bool = false
  getter last_error : Exception? = nil

  getter fps : FPS = FPS.new
  @next_fps_window : FPS = FPS.new

  # video and NN model processing
  getter input : URI | Path
  @video : FFmpeg::Video? = nil
  getter model : ModelAdaptor
  getter frame : StumpyCore::Canvas? = nil
  @channel : Channel(StumpyCore::Canvas)? = nil

  def detections
    @fps = FPS.new
    @next_fps_window = FPS.new

    invocation = 0
    @state_mutex.synchronize do
      raise "already processing" if processing?
      @processing_count += 1
      @processing = true
      invocation = @processing_count
    end

    # start processing video based on the model requirements
    nn_model = @model
    input_width, input_height = nn_model.input_resolution
    spawn { process_video(invocation, input_width, input_height) }
    spawn { track_fps(invocation) }

    # yield any detections
    channel = Channel(StumpyCore::Canvas).new(1)
    while @processing && invocation == @processing_count
      @channel = channel
      canvas = channel.receive

      if @fps.operations.zero?
        @fps.reset
        @next_fps_window.reset
      end

      @state_mutex.synchronize { @performing_detection = true }
      detections = nn_model.process(canvas)
      @state_mutex.synchronize { @performing_detection = false }

      @fps.increment
      @next_fps_window.increment
      yield(canvas, detections, @fps) unless detections.empty?
    end
  ensure
    @state_mutex.synchronize do
      @processing = false
      @performing_detection = false
    end
  end

  def stop
    @state_mutex.synchronize { @processing = false }
  end

  protected def process_video(invocation, input_width, input_height) : Nil
    # we only want to process the video once
    @state_mutex.synchronize do
      return unless @processing && invocation == @processing_count
    end

    # we capture as fast as we can, we just skip running detections if they cant keep up
    @video = video = FFmpeg::Video.open(@input)
    video.each_frame(input_width, input_height) do |canvas, _key_frame|
      @error = false
      @frame = canvas
      next if @performing_detection # skip frames as the NN is slow
      break unless @processing && invocation == @processing_count

      # pass the latest frame to the neural net
      if channel = @channel
        @channel = nil
        channel.send(canvas)
      end
    end
  rescue error
    # stream probably not online, we'll just keep retrying
    Log.trace(exception: error) { "error extracting frame" }
    @last_error = error
    @error = true
    sleep 2
    spawn { process_video(invocation, input_width, input_height) }
  end

  protected def track_fps(invocation)
    loop do
      sleep 5
      break unless @processing && invocation == @processing_count
      @fps = @next_fps_window
      @next_fps_window = FPS.new
    end
  end
end
