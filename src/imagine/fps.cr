# calculates the number of operations being performed every second
class Imagine::FPS
  def initialize
    @operations = 0_u64
    @start_time = Time.monotonic
  end

  @start_time : Time::Span
  getter operations : UInt64

  def increment
    @operations += 1_u64
  end

  def frames_per_second
    elapsed_time = Time.monotonic - @start_time
    @operations / elapsed_time.total_seconds
  end

  def reset
    @operations = 0_u64
    @start_time = Time.monotonic
  end
end
