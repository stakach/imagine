require "log"

module Imagine
  Log = ::Log.for("imagine")

  {% begin %}
    VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify.downcase }}
  {% end %}
end

require "./imagine/*"
require "./imagine/models/*"
