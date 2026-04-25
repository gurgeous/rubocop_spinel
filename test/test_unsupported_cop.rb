# tests for the Spinel unsupported-feature cop

class TestUnsupportedCop < Minitest::Test
  def test_flags_eval_family
    offenses = inspect_source(<<~RUBY)
      eval("1")
      instance_eval("1")
      class_eval("1")
      module_eval("1")
    RUBY

    assert_equal 4, offenses.length
    assert_equal [
      "Spinel does not support `eval`.",
      "Spinel does not support `instance_eval`.",
      "Spinel does not support `class_eval`.",
      "Spinel does not support `module_eval`.",
    ], offenses.map(&:message)
  end

  def test_flags_dynamic_metaprogramming
    offenses = inspect_source(<<~RUBY)
      send(:size)
      target.send(name)
      target.public_send(name)
      extend Greeter
      define_method(name) { 1 }
      method_missing(:foo)
    RUBY

    assert_equal 6, offenses.length
    assert_equal [
      "Spinel only supports `send` with a literal symbol.",
      "Spinel only supports `send` with a literal symbol.",
      "Spinel does not support `public_send`.",
      "Spinel does not support `extend`.",
      "Spinel does not support `define_method`.",
      "Spinel does not support `method_missing`.",
    ], offenses.map(&:message)
  end

  def test_flags_threads
    offenses = inspect_source(<<~RUBY)
      Thread.new { 1 }
      Mutex.new
    RUBY

    assert_equal 2, offenses.length
    assert_equal [
      "Spinel does not support threads or mutexes.",
      "Spinel does not support threads or mutexes.",
    ], offenses.map(&:message)
  end

  def test_flags_singleton_classes
    offenses = inspect_source(<<~RUBY)
      class Person
        class << self
          def greet
            42
          end
        end
      end
    RUBY

    assert_equal 1, offenses.length
    assert_equal ["Spinel does not support singleton classes."], offenses.map(&:message)
  end

  def test_allows_supported_calls
    offenses = inspect_source(<<~RUBY)
      require "set"
      system("echo hi")
      target.send(:size)
    RUBY

    assert_empty offenses
  end

  private

  def inspect_source(source)
    processed_source = RuboCop::ProcessedSource.new(source, 3.3, "test.rb")
    team.investigate(processed_source).offenses
  end

  def team
    @team ||= RuboCop::Cop::Team.new([cop], config, raise_error: true)
  end

  def cop
    @cop ||= RuboCop::Cop::Spinel::Unsupported.new(config)
  end

  def config
    @config ||= RuboCop::Config.new(
      "AllCops" => {"TargetRubyVersion" => 3.3},
      "Spinel/Unsupported" => {"Enabled" => true}
    )
  end
end
