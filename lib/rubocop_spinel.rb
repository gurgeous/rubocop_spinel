# main entrypoint for the gem

require "rubocop"

require_relative "rubocop/spinel"
require_relative "rubocop/spinel/inject"
require_relative "rubocop_spinel/version"
require_relative "rubocop/cop/spinel_cops"

module RubocopSpinel
end

RuboCop::Spinel::Inject.defaults!
