# ban Ruby features unsupported by Spinel

module RuboCop
  module Cop
    module Spinel
      class Unsupported < Base
        TOP_LEVEL_CONSTS = %i[Mutex Thread].freeze
        BANNED_METHODS = %i[
          class_eval
          define_method
          eval
          extend
          instance_eval
          method_missing
          module_eval
          public_send
        ].freeze
        RESTRICT_ON_SEND = (BANNED_METHODS + [:send]).freeze

        def on_send(node)
          return if allowed_send?(node)

          add_offense(node.loc.selector, message: message_for(node.method_name))
        end

        def on_const(node)
          return unless top_level_const?(node)
          return unless TOP_LEVEL_CONSTS.include?(node.const_name.to_sym)

          add_offense(node, message: message_for(node.const_name))
        end

        def on_sclass(node)
          add_offense(node, message: "Spinel does not support singleton classes.")
        end

        private

        def allowed_send?(node)
          node.method_name == :send && node.receiver && node.first_argument&.sym_type?
        end

        def top_level_const?(node)
          node.namespace.nil? || node.namespace.cbase_type?
        end

        def message_for(name)
          case name.to_sym
          when :send
            "Spinel only supports `send` with a literal symbol."
          when :extend
            "Spinel does not support `extend`."
          when :Thread, :Mutex
            "Spinel does not support threads or mutexes."
          else
            "Spinel does not support `#{name}`."
          end
        end
      end
    end
  end
end
