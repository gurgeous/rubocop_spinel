# ban Ruby features unsupported by Spinel

module RuboCop
  module Cop
    module Spinel
      class Unsupported < Base
        BANNED_METHODS = %i[
          class_eval
          const_get
          define_method
          define_singleton_method
          eval
          extend
          instance_eval
          method_missing
          module_eval
          module_function
          public_send
          remove_method
          singleton_method
          undef_method
        ].freeze
        RESTRICT_ON_SEND = (BANNED_METHODS + %i[prepend send]).freeze
        TOP_LEVEL_CONSTS = %i[Mutex Thread].freeze

        def on_send(node)
          # `prepend` is only unsupported as a module/class feature.
          return handle_prepend(node) if node.method_name == :prepend
          return if allowed_send?(node)

          add_offense(node.loc.selector, message: message_for(node.method_name))
        end

        def on_const(node)
          return unless top_level_const?(node)
          return unless TOP_LEVEL_CONSTS.include?(node.const_name.to_sym)

          add_offense(node, message: message_for(node.const_name))
        end

        # `class << self` compiles in Spinel but does not work correctly.
        def on_sclass(node)
          add_offense(node, message: "Spinel does not support singleton classes.")
        end

        private

        # Spinel rewrites receiver-style `obj.send(:name)` during parsing.
        def allowed_send?(node)
          node.method_name == :send && node.receiver && node.first_argument&.sym_type?
        end

        def handle_prepend(node)
          return unless unsupported_prepend?(node)

          add_offense(node.loc.selector, message: message_for(:prepend))
        end

        # Keep normal receiver calls like `str.prepend("x")` allowed.
        def unsupported_prepend?(node)
          node.method_name == :prepend && node.receiver.nil?
        end

        def top_level_const?(node)
          node.namespace.nil? || node.namespace.cbase_type?
        end

        def message_for(name)
          case name.to_sym
          when :send then "Spinel only supports `send` with a literal symbol."
          when :Thread, :Mutex then "Spinel does not support threads or mutexes."
          when :prepend then "Spinel does not support module/class `prepend`."
          else; "Spinel does not support `#{name}`."
          end
        end
      end
    end
  end
end
