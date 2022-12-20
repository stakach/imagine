require "./detection"
require "stumpy_core"

abstract class Imagine::ModelAdaptor
  abstract def input_resolution : Tuple(Int32, Int32)
  abstract def process(canvas : StumpyCore::Canvas) : Array(Detection)
end
