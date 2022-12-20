require "json"

module Imagine
  record Detection, top : Float32, left : Float32, bottom : Float32, right : Float32, classification : Int32, name : String?, score : Float32 do
    include JSON::Serializable

    def lines(height, width)
      height = height.to_f32
      width = width.to_f32

      top_px = (top * height).round.to_i
      bottom_px = (bottom * height).round.to_i
      left_px = (left * width).round.to_i
      right_px = (right * width).round.to_i

      {
        # top line
        {left_px, top_px, right_px, top_px},
        # left line
        {left_px, top_px, left_px, bottom_px},
        # right line
        {right_px, top_px, right_px, bottom_px},
        # bottom line
        {left_px, bottom_px, right_px, bottom_px},
      }
    end
  end
end
