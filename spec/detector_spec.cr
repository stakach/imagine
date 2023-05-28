require "./spec_helper"

module Imagine
  describe Imagine::Detector do
    Spec.before_each do
    end

    it "loads a model" do
      model = Model::TFLiteImage.new(SPEC_TF_L_MODEL)
      puts model.inspect
      model.input_resolution.should eq({300, 300})

      count = 0
      detector = Detector.new(SPEC_VIDEO_FILE, model)
      detector.detections do |frame, detections|
        count += 1
        break if count > 20
        puts detections.inspect
      end

      puts "\nFPS: #{detector.fps.frames_per_second}"
      count.should eq 21
    end
  end
end
