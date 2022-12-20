require "log"
require "ffmpeg"
require "tensorflow_lite"

module Imagine
  Log = ::Log.for("imagine")

  {% begin %}
    VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify.downcase }}
  {% end %}
end

require "./imagine/*"
