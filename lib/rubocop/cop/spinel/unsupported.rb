# ban Ruby features unsupported by Spinel

module RuboCop
  module Cop
    module Spinel
      class Unsupported < Base
        BANNED_METHODS = %i[
          class_eval
          const_get
          define_singleton_method
          eval
          extend
          method_missing
          module_eval
          module_function
          public_send
          remove_method
          singleton_method
          undef_method
        ].freeze
        RESTRICT_ON_SEND = (BANNED_METHODS + %i[define_method instance_eval prepend send]).freeze
        TOP_LEVEL_CONSTS = %i[Mutex Thread].freeze

        def on_send(node)
          return handle_define_method(node) if node.method_name == :define_method
          return handle_instance_eval(node) if node.method_name == :instance_eval
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
          return if supported_singleton_accessor?(node)

          add_offense(node, message: "Spinel does not support singleton classes.")
        end

        private

        def handle_define_method(node)
          return if supported_define_method?(node)

          add_offense(node.loc.selector, message: message_for(:define_method))
        end

        def handle_instance_eval(node)
          return if supported_instance_eval?(node)

          add_offense(node.loc.selector, message: message_for(:instance_eval))
        end

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

        def supported_define_method?(node)
          node.receiver.nil? && node.block_node && node.arguments.one? && node.first_argument&.sym_type?
        end

        # Spinel supports `recv.instance_eval { ... }` and the exact
        # `def m(&block); instance_eval(&block); end` trampoline shape.
        def supported_instance_eval?(node)
          supported_instance_eval_block?(node) || supported_instance_eval_trampoline?(node)
        end

        def supported_instance_eval_block?(node)
          node.receiver && node.block_node && !node.arguments?
        end

        def supported_instance_eval_trampoline?(node)
          return false unless node.receiver.nil? && node.arguments.one?

          block_pass = node.first_argument
          return false unless block_pass&.block_pass_type?

          forwarded = block_pass.children.first
          return false unless forwarded&.lvar_type?

          method_def = node.each_ancestor(:def, :defs).first
          return false unless method_def&.body == node

          block_arg = method_def.arguments.children.first
          return false unless method_def.arguments.children.one? && block_arg&.blockarg_type?

          forwarded.children.first == block_arg.children.first
        end

        def supported_singleton_accessor?(node)
          return false unless node.children.first&.self_type?
          return false unless singleton_owner(node)&.module_type?

          singleton_body(node).all? { supported_singleton_accessor_call?(_1) }
        end

        def singleton_owner(node)
          node.each_ancestor.find { _1.class_type? || _1.module_type? }
        end

        def singleton_body(node)
          return [] unless node.body

          node.body.begin_type? ? node.body.children : [node.body]
        end

        def supported_singleton_accessor_call?(node)
          node.send_type? && node.receiver.nil? && node.method?(:attr_accessor) &&
            node.arguments.all?(&:sym_type?)
        end

        def top_level_const?(node)
          node.namespace.nil? || node.namespace.cbase_type?
        end

        def message_for(name)
          case name.to_sym
          when :send then "Spinel only supports receiver-style `obj.send(:literal_symbol)`."
          when :Thread, :Mutex then "Spinel does not support threads or mutexes."
          when :prepend then "Spinel does not support module/class `prepend`."
          else; "Spinel does not support `#{name}`."
          end
        end
      end
    end
  end
end
