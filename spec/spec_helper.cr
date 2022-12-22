require "spec"
require "http/client"
require "../src/imagine"
require "../src/imagine/models/example_object_detection"

SPEC_VIDEO_FILE = Path.new "./test.mp4"
SPEC_TF_L_MODEL = Path.new "./mobilenet_v1.tflite"
# SPEC_TF_L_MODEL = Path.new "./tflite_conversions/efficient.tflite"

unless File.exists? SPEC_VIDEO_FILE
  puts "downloading video file..."
  HTTP::Client.get("https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/Big_Buck_Bunny_360_10s_5MB.mp4") do |response|
    raise "could not download video file" unless response.success?
    File.write(SPEC_VIDEO_FILE, response.body_io)
  end
end

unless File.exists? SPEC_TF_L_MODEL
  puts "downloading tensorflow model..."
  # details: https://tfhub.dev/tensorflow/lite-model/ssd_mobilenet_v1/1/metadata/2
  HTTP::Client.get("https://storage.googleapis.com/tfhub-lite-models/tensorflow/lite-model/ssd_mobilenet_v1/1/metadata/2.tflite") do |response|
    raise "could not download tf model file" unless response.success?
    File.write(SPEC_TF_L_MODEL, response.body_io)
  end
end
