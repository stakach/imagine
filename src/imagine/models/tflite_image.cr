require "tensorflow_lite/edge_tpu"
require "tflite_image"
require "../../imagine"

# Implements a model processor for TFLite Images
#
# https://github.com/spider-gazelle/tflite_image
class Imagine::Model::TFLiteImage < Imagine::ModelAdaptor
  def initialize(model : Path | URI, labels : URI? = nil, enable_tpu : Bool = true)
    delegate = if enable_tpu && TensorflowLite::EdgeTPU.devices.size > 0
                 edge_tpu = TensorflowLite::EdgeTPU.devices[0]
                 Log.info { "EdgeTPU Found! #{edge_tpu.type}: #{edge_tpu.path}" }
                 edge_tpu.to_delegate
               end

    @client = TensorflowLite::Client.new(model, delegate: delegate, labels: labels)
    Log.warn { "no labels found for model at #{model}, results may not be useful" } unless @client.labels
    @detector = TensorflowLite::Image::ObjectDetection.new(@client)
  end

  getter client : TensorflowLite::Client
  getter detector : TensorflowLite::Image::ObjectDetection

  def labels : Array(String)
    @client.labels || [] of String
  end

  def input_resolution : Tuple(Int32, Int32)
    detector.resolution
  end

  def inspect(io : IO)
    @client.interpreter.inspect(io)
  end

  def process(canvas : StumpyCore::Canvas)
    _scaled_canvas, detections = detector.run canvas
    # adjustments are made on the frontend
    detections
  end
end
