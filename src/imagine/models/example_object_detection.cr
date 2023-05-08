require "tensorflow_lite/edge_tpu"
require "../../imagine"

# TF Lite Example Application
# https://www.tensorflow.org/lite/examples/object_detection/overview
class Imagine::Model::ExampleObjectDetection < Imagine::ModelAdaptor
  def initialize(model : Path, labels : Hash(Int32, String)? = nil, enable_tpu : Bool = true)
    delegate = if enable_tpu && TensorflowLite::EdgeTPU.devices.size > 0
      edge_tpu = TensorflowLite::EdgeTPU.devices[0]
      Log.info { "EdgeTPU Found! #{edge_tpu.type}: #{edge_tpu.path}" }
      edge_tpu.to_delegate
    end

    @client = TensorflowLite::Client.new(model, delegate: delegate)
    @labels = labels ? labels : TFLite::ExtractLabels.from(model) || {} of Int32 => String
    Log.warn { "no labels found for model at #{model}, results may not be useful" } if @labels.empty?
  end

  getter client : TensorflowLite::Client
  getter labels : Hash(Int32, String)

  def input_resolution : Tuple(Int32, Int32)
    input_tensor = client[0]
    {input_tensor[1], input_tensor[2]}
  end

  def inspect(io : IO)
    io << "input tensor layers: " << client.input_tensor_count
    client.each do |tensor|
      io << "\n--- input: " << tensor.name
      io << "\n\ttype: " << tensor.type
      begin
        io << "\n\tinputs: " << tensor.io_count
      rescue
        io << "\n\tbytesize: " << tensor.bytesize
      end
      io << "\n\tdimensions: " << tensor.map(&.to_s).join("x")
    end
  end

  def process(canvas : StumpyCore::Canvas) : Array(Detection)
    # configure the inputs
    input_layer = client[0]
    case input_layer.type
    when .u_int8?
      # expects pixel intensity between 0 and 255
      # https://tfhub.dev/tensorflow/lite-model/ssd_mobilenet_v1/1/metadata/2
      inputs = client[0].as_u8
      canvas.pixels.each_with_index do |rgb, index|
        idx = index * 3
        # we need to move the images colour space into the desired range
        inputs[idx] = ((rgb.r / UInt16::MAX) * UInt8::MAX).round.to_u8
        inputs[idx + 1] = ((rgb.g / UInt16::MAX) * UInt8::MAX).round.to_u8
        inputs[idx + 2] = ((rgb.b / UInt16::MAX) * UInt8::MAX).round.to_u8
      end
    else
      raise "unsupported input data type: #{input_layer.type}"
    end

    # execute the neural net
    client.invoke!

    # collate the results (convert bounding boxes from pixels to percentages)
    outputs = client.outputs
    boxes = outputs[0].as_f32
    features = outputs[1].as_f32
    scores = outputs[2].as_f32
    detection_count = outputs[3].as_f32[0].to_i

    # transform the results
    (0...detection_count).map do |index|
      idx = index * 4
      klass = features[index].to_i
      Detection.new(
        top: boxes[idx],
        left: boxes[idx + 1],
        bottom: boxes[idx + 2],
        right: boxes[idx + 3],
        classification: klass,
        name: labels[klass]?,
        score: scores[index]
      )
    end
  end
end
