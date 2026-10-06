# flag Ruby that Spinel compiles but runs differently from CRuby

module RuboCop
  module Cop
    module Spinel
      class Divergence < Base
        include FrozenStringLiteral
        include Support

        ENCODINGS = %w[ASCII ASCII-8BIT BINARY US-ASCII UTF-8].freeze
        ENCODING_CONSTS = %i[ASCII ASCII_8BIT BINARY US_ASCII UTF_8].freeze
        ENCODING_CALLS = %i[encode encode! force_encoding].freeze
        GRAPHEMES = %i[each_grapheme_cluster grapheme_clusters].freeze
        HOOKS = %i[const_missing inherited method_added prepended singleton_method_added].freeze
        MUTATORS = %i[
          << []= capitalize! chomp! chop! clear concat delete! downcase! force_encoding gsub! insert lstrip!
          prepend replace reverse! rstrip! scrub! setbyte slice! squeeze! strip! sub! succ! swapcase! tr! tr_s! upcase!
        ].freeze
        TRACES = %i[backtrace backtrace_locations caller caller_locations].freeze
        UNCALLED = %i[method_missing respond_to_missing?].freeze
        # exceptions a Ctrl-C raises in CRuby, while it kills a Spinel program outright
        INTERRUPTS = %i[Interrupt SignalException].freeze
        INT_SIGNALS = ["INT", "SIGINT", 2].freeze
        RESTRICT_ON_SEND = (ENCODING_CALLS + GRAPHEMES + MUTATORS + TRACES + %i[__dir__]).uniq.freeze

        def on_new_investigation
          @traps_int = nil
          super
          comment = processed_source.comments.find { MagicComment.parse(_1.text).frozen_string_literal == false }
          add_offense(comment, message: "Spinel ignores `frozen_string_literal: false`; literals are always frozen.") if comment
        end

        def on_send(node)
          message = message_for(node)
          flag(node, message) if message
        end
        alias_method :on_csend, :on_send

        def on_def(node)
          name = node.method_name
          message = if UNCALLED.include?(name)
            "Spinel never calls `#{name}`; an undefined method raises NoMethodError."
          elsif HOOKS.include?(name) && class_method?(node)
            "Spinel never calls the `#{name}` hook."
          end
          flag(node, message) if message
        end
        alias_method :on_defs, :on_def

        def on_str(node)
          return unless node.source == "__FILE__" && !program_name_check?(node)

          flag(node, "Spinel resolves `__FILE__` at compile time, to the source file rather than the executable; use `$0`.")
        end

        def on_resbody(node)
          return if traps_int?

          node.exceptions.each do |exception|
            next unless exception.const_type? && INTERRUPTS.include?(exception.short_name) && top_level?(exception)

            flag(exception, "Spinel does not raise `#{exception.short_name}` on Ctrl-C; trap it with `Signal.trap(\"INT\") { raise Interrupt }`.")
          end
        end

        def on_defined?(node)
          return unless node.children.first&.type?(:super, :zsuper)

          flag(node, "Spinel's `defined?(super)` is always nil.")
        end

        def on_alias(node)
          return unless node.old_identifier.type?(:back_ref, :nth_ref)

          flag(node, "Spinel cannot alias regexp globals; the alias reads nil.")
        end

        private

        def message_for(node)
          name = node.method_name
          if MUTATORS.include?(name) && frozen_literal?(node.receiver)
            "Spinel freezes string literals; start from `+\"\"` or `String.new`."
          elsif TRACES.include?(name) && trace?(node)
            "Spinel's `#{name}` is empty outside `--debug` builds."
          elsif ENCODING_CALLS.include?(name) && foreign_encoding?(node.first_argument)
            "Spinel strings are UTF-8 or binary only."
          elsif GRAPHEMES.include?(name)
            "Spinel's `#{name}` does not join combining characters."
          elsif name == :__dir__ && node.receiver.nil? && !user_method?(name)
            "Spinel resolves `__dir__` at compile time, not to the executable's directory; locate files from `$0`."
          end
        end

        # `__FILE__ == $0`, which Spinel answers for the executable
        def program_name_check?(node)
          parent = node.parent
          return false unless parent&.send_type? && %i[== !=].include?(parent.method_name)

          other = parent.receiver.equal?(node) ? parent.first_argument : parent.receiver
          other&.gvar_type? && %i[$0 $PROGRAM_NAME].include?(other.name)
        end

        # `Signal.trap("INT") { raise Interrupt }` anywhere in the file, or a require of a feature doing so
        def traps_int?
          if @traps_int.nil?
            @traps_int = processed_source.ast.each_node(:send).any? { int_trap?(_1) } ||
              cop_config.fetch("InterruptRequires", []).any? { required?(_1) }
          end
          @traps_int
        end

        def int_trap?(node)
          return false unless node.method?(:trap)
          return false unless node.receiver.nil? || const_named?(node.receiver, :Signal)

          signal = node.first_argument
          signal&.type?(:str, :sym, :int) && INT_SIGNALS.include?(signal.sym_type? ? signal.value.to_s : signal.value)
        end

        # a string literal, or a local/ivar only ever set to one
        def frozen_literal?(recv)
          return false if recv.nil? || frozen_string_literals_enabled?
          return true if recv.str_type?
          return false unless recv.type?(:lvar, :ivar) && !attr_written?(recv)

          values = writes(recv)
          values.any? && values.all? { _1&.str_type? }
        end

        # an attr writer can store a mutable string we cannot see
        def attr_written?(var)
          return false unless var.ivar_type?

          names = processed_source.ast.each_node(:send).select { %i[attr_accessor attr_writer].include?(_1.method_name) }.flat_map(&:arguments)
          names.any? { _1.sym_type? && :"@#{_1.value}" == var.children.first }
        end

        def trace?(node)
          return !node.receiver.nil? if %i[backtrace backtrace_locations].include?(node.method_name)

          node.receiver.nil? && !user_method?(node.method_name)
        end

        def foreign_encoding?(node)
          return !ENCODINGS.include?(node.value.upcase) if node&.str_type?

          node&.const_type? && node.namespace&.const_name == "Encoding" && !ENCODING_CONSTS.include?(node.short_name)
        end

        # `def self.x`, or a def inside `class << self`
        def class_method?(node)
          return node.receiver.self_type? if node.defs_type?

          node.each_ancestor(:sclass, :class, :module, :def).first&.sclass_type?
        end
      end
    end
  end
end
