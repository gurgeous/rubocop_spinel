# tests for the Spinel divergence cop

require_relative "test_helper"

class TestDivergenceCop < CopTest
  def test_flags_never_called_methods
    assert_equal [
      "Spinel never calls `method_missing`; an undefined method raises NoMethodError.",
      "Spinel never calls `respond_to_missing?`; an undefined method raises NoMethodError.",
      "Spinel never calls the `inherited` hook.",
      "Spinel never calls the `method_added` hook.",
      "Spinel never calls the `const_missing` hook.",
    ], messages(<<~RUBY)
      class Proxy
        def method_missing(name, *args) = super
        def respond_to_missing?(name, all = false) = true
        def self.inherited(sub) = super
        class << self
          def method_added(name) = super
        end
      end
      class Object
        def self.const_missing(name) = nil
      end
    RUBY
  end

  def test_allows_hooks_spinel_calls
    assert_empty messages(<<~RUBY)
      module Concern
        def self.included(base) = base.extend(ClassMethods)
        def self.extended(base) = nil
      end
      class Item
        def inherited = false
      end
    RUBY
  end

  def test_flags_runtime_differences
    assert_equal [
      "Spinel's `defined?(super)` is always nil.",
      "Spinel's `caller` is empty outside `--debug` builds.",
      "Spinel's `backtrace` is empty outside `--debug` builds.",
      "Spinel strings are UTF-8 or binary only.",
      "Spinel strings are UTF-8 or binary only.",
      "Spinel's `grapheme_clusters` does not join combining characters.",
      "Spinel cannot alias regexp globals; the alias reads nil.",
    ], messages(<<~RUBY)
      def hi = defined?(super) ? super : 0
      warn caller.first
      rescue_me { |e| e.backtrace.first }
      s.encode("ISO-8859-1")
      s.force_encoding(Encoding::Shift_JIS)
      s.grapheme_clusters
      alias $MATCH $&
    RUBY
    assert_empty messages(<<~RUBY)
      s.encode("UTF-8")
      s.force_encoding(Encoding::BINARY)
      alias $new $old
    RUBY
  end

  def test_flags_frozen_literal_mutation
    assert_equal [
      "Spinel freezes string literals; start from `+\"\"` or `String.new`.",
      "Spinel freezes string literals; start from `+\"\"` or `String.new`.",
      "Spinel freezes string literals; start from `+\"\"` or `String.new`.",
    ], messages(<<~RUBY)
      buf = ""
      buf << "x"
      "abc".upcase!
      class Log
        def initialize = @out = ""
        def add(x) = @out << x
      end
    RUBY
  end

  def test_allows_mutable_strings
    assert_empty messages(<<~RUBY)
      a = +""
      a << "x"
      b = String.new
      b << "x"
      c = "n=\#{n}"
      c << "!"
      d = ""
      d = d.dup
      d << "x"
      class Log
        attr_writer :out
        def initialize = @out = ""
        def add(x) = @out << x
      end
    RUBY
  end

  def test_frozen_string_literal_comment
    assert_empty messages(<<~RUBY)
      # frozen_string_literal: true
      buf = ""
      buf << "x"
    RUBY
    assert_equal ["Spinel ignores `frozen_string_literal: false`; literals are always frozen."], messages(<<~RUBY)
      # frozen_string_literal: false
      x = 1
    RUBY
  end

  def test_flags_source_locations
    assert_equal [
      "Spinel resolves `__dir__` at compile time, not to the executable's directory; locate files from `$0`.",
      "Spinel resolves `__FILE__` at compile time, to the source file rather than the executable; use `$0`.",
    ], messages(<<~RUBY)
      system "\#{__dir__}/k run app"
      k_executable = File.expand_path(__FILE__)
    RUBY
    assert_empty messages(<<~RUBY)
      main if __FILE__ == $0
      main if $PROGRAM_NAME == __FILE__
      require_relative "lib/helper"
      puts "__FILE__"
    RUBY
  end

  def test_flags_interrupt_rescues
    assert_equal [
      "Spinel does not raise `Interrupt` on Ctrl-C; trap it with `Signal.trap(\"INT\") { raise Interrupt }`.",
      "Spinel does not raise `SignalException` on Ctrl-C; trap it with `Signal.trap(\"INT\") { raise Interrupt }`.",
    ], messages(<<~RUBY)
      begin
        run
      rescue Interrupt
        exit
      end
      begin
        run
      rescue IOError, SignalException => e
        exit 128 + e.signo
      end
    RUBY
    assert_empty messages(<<~RUBY)
      Signal.trap("INT") { raise Interrupt }
      begin
        run
      rescue Interrupt
        exit
      end
    RUBY
    configure("InterruptRequires" => ["sigint_interrupt"])
    assert_empty messages(<<~RUBY)
      require "sigint_interrupt" if RUBY_ENGINE == "spinel"
      begin
        run
      rescue Interrupt
        exit
      end
    RUBY
    assert_empty messages(<<~RUBY)
      trap(:INT) { raise Interrupt }
      def run
        work
      rescue SignalException
        exit
      end
    RUBY
  end

  private

  def cop_class = RuboCop::Cop::Spinel::Divergence
end
