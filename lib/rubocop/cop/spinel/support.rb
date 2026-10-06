# helpers shared by the Spinel cops

module RuboCop
  module Cop
    module Spinel
      module Support
        WRITES = {cvar: :cvasgn, gvar: :gvasgn, ivar: :ivasgn, lvar: :lvasgn}.freeze

        def on_new_investigation
          @user_methods = @user_classes = nil
          super
        end

        private

        # Spinel drops a branch that a `RUBY_ENGINE == "..."` check rules out, so
        # code kept there for other engines never reaches the compiler.
        def flag(node, message, &)
          add_offense(highlight(node), message:, &) unless dropped_by_spinel?(node)
        end

        # the method name of a call or def, the header of `class << x`
        def highlight(node)
          case node.type
          when :send, :csend then node.loc.respond_to?(:selector) && node.loc.selector || node
          when :def, :defs then node.loc.keyword.join(node.loc.name)
          when :sclass then node.loc.keyword.join(node.children.first.source_range)
          else node
          end
        end

        def dropped_by_spinel?(node)
          [node, *node.each_ancestor].each_cons(2).any? do |child, parent|
            dead_branch?(parent, child) || after_exit?(parent, child)
          end
        end

        # `if RUBY_ENGINE == "spinel" then ... else <dead> end`
        def dead_branch?(parent, child)
          return false unless parent.if_type?

          live = spinel_check(parent.condition)
          return false if live.nil?

          child.equal?(branch(parent, !live))
        end

        # `return x if RUBY_ENGINE == "spinel"` ahead of <dead>
        def after_exit?(parent, child)
          return false unless parent.begin_type?

          parent.children.take_while { !_1.equal?(child) }.any? { exit_guard?(_1) }
        end

        def exit_guard?(node)
          return false unless node.if_type?

          live = spinel_check(node.condition)
          return false if live.nil?

          branch(node, live)&.type?(:return, :next, :break)
        end

        # what `RUBY_ENGINE == "x"` (or `!=`) evaluates to under Spinel, else nil
        def spinel_check(node)
          node = node.children.first while node&.begin_type? && node.children.one?
          return unless node&.send_type? && %i[== !=].include?(node.method_name)

          engine, str = engine_const?(node.receiver) ? [node.receiver, node.first_argument] : [node.first_argument, node.receiver]
          return unless engine_const?(engine) && str&.str_type?

          (str.value == "spinel") == node.method?(:==)
        end

        # values written to a local (in its method), an ivar/cvar (in its class) or a global
        def writes(var)
          type = WRITES.fetch(var.type)
          # the receiver of `def o.m` lives outside that def
          from = (var.parent&.defs_type? && var.parent.receiver.equal?(var)) ? var.parent : var
          scope = case var.type
          when :lvar then from.each_ancestor(:def, :defs).first
          when :ivar, :cvar then from.each_ancestor(:class, :module).first
          end || processed_source.ast
          name = var.children.first
          assigns = scope.each_node(type).select { _1.name == name }.map(&:expression)
          or_assigns = scope.each_node(:or_asgn).select { _1.assignment_node.type == type && _1.assignment_node.name == name }
          assigns + or_assigns.map(&:expression)
        end

        # `require "feature"` anywhere in the file, in any branch
        def required?(feature)
          processed_source.ast.each_node(:send).any? { _1.method?(:require) && _1.receiver.nil? && _1.first_argument&.str_type? && _1.first_argument.value == feature }
        end

        # a program that defines (or aliases) the name itself is calling its own method
        def user_method?(name)
          @user_methods ||= begin
            ast = processed_source.ast
            aliases = ast.each_node(:alias).filter_map { _1.new_identifier.value if _1.new_identifier.sym_type? }
            (ast.each_node(:def, :defs).map(&:method_name) + aliases).to_set
          end
          @user_methods.include?(name)
        end

        # a class or constant the program defines itself (`class String` in a namespace)
        def user_class?(name)
          @user_classes ||= processed_source.ast.each_node(:class, :module, :casgn).map { _1.casgn_type? ? _1.name : _1.identifier.short_name }.to_set
          @user_classes.include?(name)
        end

        def engine_const?(node)
          node&.const_type? && node.short_name == :RUBY_ENGINE && top_level?(node)
        end

        # one-liners

        def branch(node, truthy) = node.children[truthy ? 1 : 2] # raw: `unless` is not swapped
        def const_named?(node, name) = node&.const_type? && node.short_name == name
        def top_level?(node) = node.namespace.nil? || node.namespace.cbase_type?
      end
    end
  end
end
