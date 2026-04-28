# tests for the Spinel unsupported-feature cop

require_relative "test_helper"

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
      Foo.const_get(:BAR)
      extend Greeter
      define_method(name) { 1 }
      define_singleton_method(:x) { 1 }
      method_missing(:foo)
      module_function :foo
      singleton_method(:foo)
      remove_method :foo
      undef_method :foo
    RUBY

    assert_equal 12, offenses.length
    assert_equal [
      "Spinel only supports receiver-style `obj.send(:literal_symbol)`.",
      "Spinel only supports receiver-style `obj.send(:literal_symbol)`.",
      "Spinel does not support `public_send`.",
      "Spinel does not support `const_get`.",
      "Spinel does not support `extend`.",
      "Spinel does not support `define_method`.",
      "Spinel does not support `define_singleton_method`.",
      "Spinel does not support `method_missing`.",
      "Spinel does not support `module_function`.",
      "Spinel does not support `singleton_method`.",
      "Spinel does not support `remove_method`.",
      "Spinel does not support `undef_method`.",
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

  def test_flags_module_prepend_but_allows_receiver_prepend
    offenses = inspect_source(<<~RUBY)
      prepend Greeter
      name.prepend("x")
    RUBY

    assert_equal 1, offenses.length
    assert_equal ["Spinel does not support module/class `prepend`."], offenses.map(&:message)
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
