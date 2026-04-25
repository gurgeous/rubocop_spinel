# inject default cop config into RuboCop

require "rubocop"

module RuboCop
  module Spinel
    module Inject
      def self.defaults!
        path = File.expand_path("../../../config/default.yml", __dir__)
        hash = RuboCop::ConfigLoader.send(:load_yaml_configuration, path)
        config = RuboCop::Config.new(hash, path)

        RuboCop::ConfigLoader.default_configuration =
          RuboCop::ConfigLoader.merge_with_default(config, path)
      end
    end
  end
end
