class Imagine::Processor(Input, Output)
  def initialize(@name : String, &@work : Input -> Output)
    spawn { process_loop }
  end

  @work : Proc(Input, Output)
  @in : Channel(Input) = Channel(Input).new
  @out : Channel(Output) = Channel(Output).new
  getter time : Time::Span = 0.seconds

  # non-blocking send
  def process(input : Input) : Bool
    select
    when @in.send(input) then true
    else
      false
    end
  end

  # output
  def receive : Output
    @out.receive
  end

  # :ditto:
  def receive? : Output?
    @out.receive?
  end

  # :nodoc:
  def finalize
    stop
  end

  # shutdown processing
  def stop
    @in.close
    @out.close
  end

  protected def process_loop
    loop do
      return if @in.closed?
      begin
        input = @in.receive
        t1 = Time.monotonic
        output = @work.call input
        t2 = Time.monotonic
        @time = t2 - t1
        @out.send output
      rescue error
        return if @in.closed?
        Log.error(exception: error) { "error performing #{@name}" }
      end
    end
  end
end
