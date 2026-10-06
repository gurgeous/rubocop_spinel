# shared test setup

require "minitest/autorun"
require "minitest/pride"
require "rubocop_spinel"

# runs one Spinel cop, configured from config/default.yml, over a snippet
class CopTest < Minitest::Test
  private

  def messages(source)
    processed_source = RuboCop::ProcessedSource.new(source, config.target_ruby_version, "test.rb")
    team = RuboCop::Cop::Team.new([cop_class.new(config)], config, raise_error: true)
    team.investigate(processed_source).offenses.map(&:message)
  end

  def config
    @config ||= RuboCop::Config.new(
      YAML.load_file(File.expand_path("../config/default.yml", __dir__)).merge("AllCops" => {"TargetRubyVersion" => 3.3})
    )
  end

  # overrides settings of the cop under test, eg. `configure("AllowedRequires" => ["yaml"])`
  def configure(settings)
    name = cop_class.cop_name
    @config = RuboCop::Config.new(config.to_h.merge(name => config.for_cop(name).merge(settings)))
  end

  def target_ruby(version)
    @config = RuboCop::Config.new(config.to_h.merge("AllCops" => config.for_all_cops.merge("TargetRubyVersion" => version)))
  end

  # the snippet after the cop's autocorrections
  def autocorrect(source)
    processed_source = RuboCop::ProcessedSource.new(source, config.target_ruby_version, "test.rb")
    commissioner = RuboCop::Cop::Commissioner.new([cop_class.new(config, autocorrect: true)], [], raise_error: true)
    corrector = commissioner.investigate(processed_source).correctors.compact.first
    corrector ? corrector.rewrite : source
  end
end
