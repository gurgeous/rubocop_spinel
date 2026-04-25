# main entrypoint for the gem

require "rubocop"

require_relative "rubocop/spinel"
require_relative "rubocop/spinel/plugin"
require_relative "rubocop/cop/spinel_cops"
