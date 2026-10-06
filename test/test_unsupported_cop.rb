# tests for the Spinel unsupported-feature cop

require_relative "test_helper"

class TestUnsupportedCop < CopTest
  def test_flags_string_eval
    assert_equal [
      "Spinel does not support `eval` of a string.",
      "Spinel does not support `class_eval` with a string; use the block form.",
      "Spinel does not support `instance_eval` with a string; use the block form.",
    ], messages(<<~RUBY)
      eval("1")
      Foo.class_eval("def x = 1")
      obj.instance_eval("@x")
    RUBY
  end

  def test_allows_block_evals_and_class_body_macros
    assert_empty messages(<<~RUBY)
      class Foo
        class_eval "def x = 1"
        class_eval { def y = 1 }
      end
      obj.instance_eval { add(1) }
      obj.instance_exec(2) { |n| n }
      def configure(&block)
        log(block)
        instance_eval(&block)
      end
    RUBY
  end

  def test_allows_features_spinel_now_supports
    assert_empty messages(<<~RUBY)
      Thread.new { Mutex.new.synchronize { 1 } }
      target.send(name)
      target.public_send(:size)
      Foo.const_get(name)
      "x".prepend("y")
      class Person
        prepend Loud
        extend Greeter
        define_singleton_method(:build) { new }
        class << self
          def greet = "hi"
        end
      end
      module Helpers
        extend self
        def count = 1
        module_function :count
      end
    RUBY
  end

  def test_skips_code_ruled_out_by_ruby_engine
    assert_empty messages(<<~RUBY)
      if RUBY_ENGINE == "spinel"
        1
      else
        eval(code)
      end
      unless RUBY_ENGINE == "spinel"
        eval(code)
      end
      RUBY_ENGINE != "spinel" ? binding : nil
      def check(code)
        return :aot if RUBY_ENGINE == "spinel"
        eval(code)
      end
    RUBY
  end

  def test_skips_methods_the_program_defines
    assert_empty messages(<<~RUBY)
      def eval(node) = node
      eval(1)
    RUBY
  end

  def test_flags_runtime_removal
    assert_equal [
      "Spinel does not support `remove_method`.",
      "Spinel does not support `undef_method`.",
      "Spinel does not support `remove_const`.",
      "Spinel does not support `singleton_method`.",
    ], messages(<<~RUBY)
      remove_method :a
      undef_method :a
      Object.send(:remove_const, :X)
      Foo.singleton_method(:a)
    RUBY
  end

  def test_define_method
    assert_empty messages(<<~RUBY)
      class Foo
        define_method(:zero) { 0 }
        define_method(:sq, ->(x) { x * x })
        %i[a b].each { |n| define_method(n) { n } }
        [1, 2].each { |n| define_method("value_\#{n}") { n } }
      end
    RUBY
    assert_equal [
      "Spinel only supports `define_method` with a literal name in a class body.",
      "Spinel only supports `define_method` with a literal name in a class body.",
      "Spinel only supports `define_method` with a literal name in a class body.",
      "Spinel only supports `define_method` in the class body, not on a receiver.",
    ], messages(<<~RUBY)
      class Foo
        define_method(name) { 0 }
        FIELDS.each { |f| define_method(f) { f } }
        def setup = define_method(:x) { 1 }
      end
      Foo.define_method(:hi) { 1 }
    RUBY
  end

  def test_allows_singleton_methods_on_traceable_receivers
    assert_empty messages(<<~RUBY)
      o = Point.new
      def o.hi = 1
      o.extend(Greeter)
      class << o
        def bye = 2
      end
      OBJ = Point.new
      OBJ.define_singleton_method(:x) { 1 }
      def Point.origin = new
      module Concern
        def self.included(base)
          base.extend(ClassMethods)
          base.include(Helpers)
        end
      end
    RUBY
  end

  def test_flags_singleton_methods_on_untraceable_receivers
    assert_equal [
      "Spinel only supports singleton methods on self in a class body, or on a class or an object assigned `Klass.new`.",
      "Spinel only supports `extend` in a class body, or on an object assigned `Klass.new`.",
      "Spinel only supports `class << self` in a class body, or on a class or an object assigned `Klass.new`.",
      "Spinel only supports `extend` in a class body, or on an object assigned `Klass.new`.",
      "Spinel only supports `define_singleton_method` in a class body, or on an object assigned `Klass.new`.",
      "Spinel only supports `extend self` in a module.",
    ], messages(<<~RUBY)
      o = Object.new
      def o.hi = 1
      build.extend(Greeter)
      class << factory
      end
      Point.extend(Greeter)
      class Point
        def initialize = define_singleton_method(:x) { 1 }
        extend self
      end
    RUBY
  end

  def test_flags_class_structure
    assert_equal [
      "Spinel only supports `include` in the class body, not on a receiver.",
      "Spinel only supports `attr_accessor` in the class body, not on a receiver.",
      "Spinel only supports `include` in the class body, not on a receiver.",
      "Spinel only supports `include` of a constant module.",
      "Spinel only supports a constant superclass.",
      "Spinel does not support subclassing `Array`; wrap it in an instance variable.",
      "Spinel does not support subclassing `Hash`; wrap it in an instance variable.",
      "Spinel does not support a class named `Process`, the builtin module.",
      "Spinel does not support `Struct.new` with a string name; use `Name = Struct.new(...)`.",
    ], messages(<<~RUBY)
      Foo.include(Greeter)
      Foo.attr_accessor :x
      Foo.send(:include, Greeter)
      class D
        include pick(Greeter)
      end
      class A < parent; end
      class Stack < Array; end
      Registry = Class.new(Hash)
      module Jobs
        class Process; end
      end
      Struct.new("Pair", :a, :b)
    RUBY
  end

  def test_allows_static_class_structure
    assert_empty messages(<<~RUBY)
      class A < Struct.new(:a); end
      class B < Data.define(:b); end
      class C < (Base); end
      class D
        singleton_class.include(Greeter)
        singleton_class.attr_accessor :level
      end
      module Shop
        class String; end
        class Fancy < String; end
      end
    RUBY
  end

  def test_flags_reflection
    assert_equal [
      "Spinel only supports `binding.local_variable_get(:name)` and friends.",
      "Spinel does not support `local_variables`.",
      "Spinel only supports `instance_variable_get` with a literal name.",
      "Spinel only supports `instance_variable_set` with a literal name.",
      "Spinel only supports `alias_method` with a literal name.",
      "Spinel only supports `method_defined?` with a literal name.",
      "Spinel does not support `singleton_class` as an object.",
      "Spinel does not support `ObjectSpace` (except `define_finalizer`).",
      "Spinel does not support `ObjectSpace` (except `define_finalizer`).",
      "Spinel does not support `TracePoint`.",
      "Spinel does not support `set_trace_func`.",
    ], messages(<<~RUBY)
      ERB.new(t).result(binding)
      local_variables
      obj.instance_variable_get(name)
      instance_variable_set("@\#{k}", v)
      alias_method name, :a
      Foo.method_defined?(name)
      obj.singleton_class
      ObjectSpace.each_object(Class)
      ObjectSpace::WeakMap.new
      TracePoint.new(:call) {}
      set_trace_func(nil)
    RUBY
    assert_empty messages(<<~RUBY)
      binding.local_variable_get(:x)
      obj.instance_variable_get(:@a)
      ObjectSpace.define_finalizer(obj, pr)
    RUBY
  end

  def test_flags_runtime_features
    assert_equal [
      "Spinel does not support `fork`; use `Process.spawn` or threads.",
      "Spinel does not support `fork`; use `Process.spawn` or threads.",
      "Spinel does not support `load`; use `require_relative`.",
      "Spinel does not support `IO.popen`; use `Open3.capture2` or `Process.spawn`.",
      "Spinel does not support refinements; reopen the class instead.",
      "Spinel does not support refinements; reopen the class instead.",
      "Spinel does not support `callcc`.",
      "Spinel does not support `ruby2_keywords`.",
      "Spinel does not support `compare_by_identity`; key by an explicit id.",
      "Spinel does not support `unicode_normalize`.",
      "Spinel does not support `slice_before` with a Proc; use the block form.",
      "Spinel does not support `DATA` / `__END__`.",
      "Spinel does not support flip-flops; use a boolean variable.",
    ], messages(<<~RUBY)
      fork { 1 }
      Process.fork { 1 }
      load "x.rb"
      IO.popen(["ls"])
      module Shout
        refine(String) { def shout = upcase }
      end
      using Shout
      callcc { |k| k }
      ruby2_keywords def fwd(*args) = target(*args)
      {}.compare_by_identity
      s.unicode_normalize(:nfc)
      list.slice_before(->(x) { x.even? })
      DATA.read
      (1..9).each { |i| p i if (i == 3)..(i == 5) }
    RUBY
  end

  def test_flags_unsupported_requires
    assert_equal ["Spinel does not provide `require \"date\"`."], messages(<<~RUBY)
      require "date"
      require "json"
      require_relative "date"
    RUBY
  end

  def test_allowed_requires
    configure("AllowedRequires" => %w[yaml did_you_mean])
    assert_equal ["Spinel does not provide `require \"date\"`."], messages(<<~RUBY)
      require "date"
      require "yaml"
      require "did_you_mean"
    RUBY
  end

  def test_flags_did_you_mean
    assert_equal ["Spinel does not provide `DidYouMean`, which CRuby loads at boot."], messages(<<~RUBY)
      DidYouMean::SpellChecker.new(dictionary: names).correct(name)
    RUBY
    # requiring it moves the question to the require, which AllowedRequires answers
    assert_equal ["Spinel does not provide `require \"did_you_mean\"`."], messages(<<~RUBY)
      require "did_you_mean" if RUBY_ENGINE == "spinel"
      DidYouMean::SpellChecker.new(dictionary: names).correct(name)
    RUBY
    assert_empty messages(<<~RUBY)
      module DidYouMean; end
      DidYouMean::SpellChecker
    RUBY
  end

  def test_flags_method_lists
    assert_equal [
      "Spinel does not support `private_methods`; list the methods explicitly.",
      "Spinel does not support `protected_methods`; list the methods explicitly.",
      "Spinel does not support a receiverless `methods` at the top level.",
      "Spinel does not support a receiverless `public_methods` at the top level.",
      "Spinel does not support a receiverless `respond_to?` at the top level.",
      "Spinel does not support a receiverless `respond_to?` at the top level.",
    ], messages(<<~RUBY)
      COMMANDS = private_methods - Object.private_instance_methods
      obj.protected_methods
      methods.grep(/^cmd_/)
      public_methods
      send(name) if respond_to?(name, true)
      names.each { |name| puts name if respond_to?(name) }
    RUBY
    assert_empty messages(<<~RUBY)
      obj.methods
      obj.public_methods(false)
      Foo.instance_methods(false)
      Foo.private_instance_methods(false)
      Foo.singleton_methods
      self.respond_to?(:x)
      1.respond_to?(:succ, true)
      class Foo
        def has?(name) = respond_to?(name)
        def list = methods
      end
    RUBY
  end

  def test_flags_time_parsing
    assert_equal [
      "Spinel does not provide `Time.parse`; build the Time from its parts, eg. with `Time.at` or `Time.new`.",
      "Spinel does not provide `Time.iso8601`; build the Time from its parts, eg. with `Time.at` or `Time.new`.",
      "Spinel does not provide `Time.strptime`; build the Time from its parts, eg. with `Time.at` or `Time.new`.",
    ], messages(<<~RUBY)
      require "time"
      Time.parse(line)
      ::Time.iso8601(stamp)
      Time.strptime(date, "%Y-%m-%d")
    RUBY
    assert_empty messages(<<~RUBY)
      Time.now.iso8601
      Time.at(stamp.to_i)
      Date.parse(line)
      JSON.parse(body)
    RUBY
  end

  def test_flags_method_objects_of_native_functions
    assert_equal [
      "Spinel cannot make a Method of the native `Base64.strict_decode64`; call it in a block.",
      "Spinel cannot make a Method of the native `JSON.parse`; call it in a block.",
      "Spinel cannot make a Method of the native `Digest::SHA256.hexdigest`; call it in a block.",
    ], messages(<<~RUBY)
      env.transform_values(&Base64.method(:strict_decode64))
      lines.map(&JSON.method(:parse))
      Digest::SHA256.method(:hexdigest)
    RUBY
    assert_empty messages(<<~RUBY)
      env.transform_values { |value| Base64.strict_decode64(value) }
      lines.map(&URI.method(:parse))
      names.map(&method(:shout))
    RUBY
  end

  def test_flags_constant_assignment_in_conditions
    message = "Spinel does not support assigning a constant in a condition; assign it first."
    assert_equal [message] * 5, messages(<<~RUBY)
      if (CONTEXT = CONFIG["contexts"][NAME])
        puts CONTEXT
      end
      puts CONTEXT unless (CONTEXT = CONFIG["context"])
      if a
      elsif (B = b)
      end
      while (LINE = gets); end
      (X = x) ? X : 0
    RUBY
    assert_empty messages(<<~RUBY)
      CONTEXT = CONFIG["contexts"][NAME]
      if CONTEXT
        puts CONTEXT
      end
      if (value = env["value"])
        puts value
      end
    RUBY
  end

  def test_autocorrects_native_method_objects_to_blocks
    target_ruby(3.4)
    assert_equal <<~RUBY, autocorrect(<<~RUBY)
      env.transform_values { Base64.strict_decode64(it) }
      lines.map { JSON.parse(it) }
      sizes.sum(0) { Digest::SHA256.hexdigest(it) }
    RUBY
      env.transform_values(&Base64.method(:strict_decode64))
      lines.map &JSON.method(:parse)
      sizes.sum(0, &Digest::SHA256.method(:hexdigest))
    RUBY
    target_ruby(3.3)
    assert_equal "lines.map { JSON.parse(_1) }\n", autocorrect("lines.map(&JSON.method(:parse))\n")
  end

  def test_leaves_native_method_objects_without_a_safe_block
    source = <<~RUBY
      pairs.inject(&JSON.method(:generate))
      parse = JSON.method(:parse)
      rows.each { _1.map(&JSON.method(:parse)) }
    RUBY
    target_ruby(3.3)
    assert_equal source, autocorrect(source)
  end

  def test_autocorrects_proc_patterns_to_blocks
    assert_equal <<~RUBY, autocorrect(<<~RUBY)
      list.slice_before { |x| x.even? }
      list.slice_after { |x| x > 1 }
      p list.slice_before { |line|
        line.start_with?("#")
      }
    RUBY
      list.slice_before(->(x) { x.even? })
      list.slice_after(lambda { |x| x > 1 })
      p list.slice_before(->(line) do
        line.start_with?("#")
      end)
    RUBY
    source = <<~RUBY
      list.slice_before(->(x) { return true if x.nil?; x.even? })
      list.slice_before(heading)
      heading = ->(x) { x.even? }
    RUBY
    assert_equal source, autocorrect(source)
  end

  def test_autocorrects_constant_assignment_in_conditions
    assert_equal <<~RUBY, autocorrect(<<~RUBY)
      CONTEXT = CONFIG["contexts"][NAME]
      if CONTEXT
        puts CONTEXT
      end
      module Limits
        LIMIT = ENV["LIMIT"]
        puts LIMIT unless LIMIT
      end
      X = x
      X ? X : 0
    RUBY
      if (CONTEXT = CONFIG["contexts"][NAME])
        puts CONTEXT
      end
      module Limits
        puts LIMIT unless (LIMIT = ENV["LIMIT"])
      end
      (X = x) ? X : 0
    RUBY
    source = <<~RUBY
      if a
      elsif (B = b)
      end
      while (LINE = gets); end
      puts(if (C = c) then C end)
    RUBY
    assert_equal source, autocorrect(source)
  end

  private

  def cop_class = RuboCop::Cop::Spinel::Unsupported
end
