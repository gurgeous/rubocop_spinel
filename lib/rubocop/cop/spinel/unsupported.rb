# flag Ruby that Spinel refuses to compile or cannot run

module RuboCop
  module Cop
    module Spinel
      class Unsupported < Base
        extend AutoCorrector
        include Support

        # refused whatever the receiver
        ANY_RECEIVER = %i[
          attached_object compare_by_identity remove_class_variable remove_const remove_method
          ruby2_keywords ruby2_keywords_hash ruby2_keywords_hash? singleton_method undef_method
          unicode_normalize unicode_normalize! unicode_normalized?
        ].freeze
        # refused as bare (or `Kernel.`) calls
        KERNEL = %i[binding callcc eval fork load local_variables set_trace_func trace_var untrace_var].freeze
        # class body declarations, resolved at compile time
        DECLARATIONS = %i[
          alias_method attr_accessor attr_reader attr_writer define_method include module_function prepend
          private private_class_method private_constant protected public public_class_method
        ].freeze
        EVALS = %i[class_eval instance_eval module_eval].freeze
        LITERAL_NAMES = %i[alias_method instance_variable_defined? instance_variable_get instance_variable_set method_defined?].freeze
        BINDING_LOCALS = %i[local_variable_defined? local_variable_get].freeze
        HOOKS = %i[extended included inherited prepended].freeze
        SENDS = %i[__send__ public_send send].freeze
        # method lists Spinel cannot build: on any receiver, or receiverless at the top level
        METHOD_LISTS = %i[private_methods protected_methods].freeze
        TOP_LEVEL_REFLECTION = %i[methods public_methods respond_to?].freeze
        # `require "time"` compiles, but these class methods are missing
        TIME_PARSERS = %i[httpdate iso8601 parse rfc2822 rfc822 strptime xmlschema].freeze
        # packages whose functions are native, so they have no Method object
        NATIVE_FUNCTION_MODULES = %i[Base64 Digest JSON].freeze
        # iterators yielding one value, so `&mod.method(:f)` and `{ mod.f(it) }` are the same
        ONE_VALUE_ITERATORS = %i[
          all? any? collect collect! collect_concat count detect drop_while each each_entry each_key each_value
          filter filter! filter_map find find_all find_index flat_map group_by map map! max_by min_by none? one?
          partition reject reject! select select! sort_by sort_by! sum take_while to_h transform_keys
          transform_values uniq uniq!
        ].freeze
        RESTRICT_ON_SEND = (
          ANY_RECEIVER + KERNEL + DECLARATIONS + EVALS + LITERAL_NAMES + SENDS + METHOD_LISTS + TOP_LEVEL_REFLECTION + TIME_PARSERS +
          %i[class_exec define_singleton_method extend method module_exec new popen refine require singleton_class slice_after slice_before using]
        ).uniq.freeze

        BUILTIN_CLASSES = %i[
          Array Complex ConditionVariable Dir Enumerator FalseClass Fiber File Float Hash Integer IO MatchData
          Method Mutex NilClass OpenStruct Proc Queue Random Range Rational Regexp SizedQueue String StringIO
          Symbol Thread Time TrueClass UnboundMethod
        ].freeze
        BUILTIN_MODULES = %i[Comparable Enumerable Errno FileTest GC Kernel Marshal Math ObjectSpace Process Signal Warning].freeze
        # `Klass.new` values Spinel cannot attach singleton methods to
        UNTRACEABLE = (BUILTIN_CLASSES + %i[BasicObject Data Object Struct]).freeze
        # ObjectSpace calls that need no allocation registry
        OBJECT_SPACE_OK = %i[const_defined? define_finalizer undefine_finalizer].freeze

        CONSTANT_CONDITION = "Spinel does not support assigning a constant in a condition; assign it first."
        MESSAGES = {
          binding: "Spinel only supports `binding.local_variable_get(:name)` and friends.",
          compare_by_identity: "Spinel does not support `compare_by_identity`; key by an explicit id.",
          eval: "Spinel does not support `eval` of a string.",
          fork: "Spinel does not support `fork`; use `Process.spawn` or threads.",
          load: "Spinel does not support `load`; use `require_relative`.",
        }.freeze

        def on_send(node)
          message = message_for(node)
          flag(node, message) { correct_call(_1, node) } if message
        end
        alias_method :on_csend, :on_send

        def on_const(node)
          return unless top_level?(node)

          message = case node.short_name
          when :DATA then "Spinel does not support `DATA` / `__END__`." unless user_class?(:DATA)
          when :DidYouMean then did_you_mean_message
          when :ObjectSpace then "Spinel does not support `ObjectSpace` (except `define_finalizer`)." if object_space_use?(node)
          when :TracePoint then unsupported(:TracePoint)
          end
          flag(node, message) if message
        end

        def on_if(node)
          return unless constant_assignment?(node.condition)

          flag(node.condition, CONSTANT_CONDITION) { hoist_constant(_1, node) }
        end

        def on_while(node)
          flag(node.condition, CONSTANT_CONDITION) if constant_assignment?(node.condition)
        end
        alias_method :on_until, :on_while
        alias_method :on_while_post, :on_while
        alias_method :on_until_post, :on_while

        def on_class(node)
          name = node.identifier.short_name
          flag(node.identifier, "Spinel does not support a class named `#{name}`, the builtin module.") if BUILTIN_MODULES.include?(name)
          message = superclass_message(node.parent_class)
          flag(node.parent_class, message) if message
        end

        def on_sclass(node)
          return if singleton_target?(node, node.children.first)

          flag(node, "Spinel only supports `class << self` in a class body, or on a class or an object assigned `Klass.new`.")
        end

        def on_defs(node)
          return if singleton_target?(node, node.receiver)

          flag(node, "Spinel only supports singleton methods on self in a class body, or on a class or an object assigned `Klass.new`.")
        end

        def on_flipflop(node)
          flag(node, "Spinel does not support flip-flops; use a boolean variable.")
        end
        alias_method :on_iflipflop, :on_flipflop
        alias_method :on_eflipflop, :on_flipflop

        private

        def message_for(node)
          name = call_name(node)
          return time_parser_message(name) if TIME_PARSERS.include?(name) && builtin_receiver?(node, :Time)
          return native_method_message(node) if name == :method && native_function_module?(node.receiver)
          return if user_method?(name) && !%i[new require].include?(name)
          return method_list_message(name) if METHOD_LISTS.include?(name)
          return top_level_reflection_message(node, name) if TOP_LEVEL_REFLECTION.include?(name)
          return unsupported(name) if ANY_RECEIVER.include?(name)
          return kernel_message(node, name) if KERNEL.include?(name)
          return "Spinel only supports `#{name}` in the class body, not on a receiver." if DECLARATIONS.include?(name) && foreign_receiver?(node)

          case name
          when :define_method then define_method_message(node)
          when :define_singleton_method, :extend then singleton_message(node, name)
          when :include, :prepend then mixin_message(node, name)
          when *EVALS, :class_exec, :module_exec then eval_message(node, name)
          when :new then new_message(node)
          when :popen then "Spinel does not support `IO.popen`; use `Open3.capture2` or `Process.spawn`." if const_receiver?(node, :IO)
          when :refine, :using then refinement_message(node, name)
          when :require then require_message(node)
          when :singleton_class then singleton_class_message(node)
          when :slice_after, :slice_before then "Spinel does not support `#{name}` with a Proc; use the block form." if proc_arg?(node.first_argument)
          else literal_name_message(node, name) if LITERAL_NAMES.include?(name)
          end
        end

        def kernel_message(node, name)
          kernel = node.receiver.nil? || const_receiver?(node, :Kernel) || (name == :fork && const_receiver?(node, :Process))
          return if !kernel || (name == :binding && binding_local?(node))

          unsupported(name)
        end

        def define_method_message(node)
          return if !in_instance_method?(node) && static_name?(call_args(node).first)

          "Spinel only supports `define_method` with a literal name in a class body."
        end

        # `extend M` / `define_singleton_method` need self in a class body, or an object traced to `Klass.new`
        def singleton_message(node, name)
          recv = node.receiver
          if recv && !recv.self_type?
            return if (name == :extend) ? traceable?(recv) || (direct?(node) && hook_param?(recv)) : singleton_target?(node, recv)
          elsif !in_instance_method?(node)
            return if name == :define_singleton_method
            return mixin_message(node, name) unless call_args(node).any?(&:self_type?)
            return if singleton_owner(node)&.module_type?

            return "Spinel only supports `extend self` in a module."
          end
          "Spinel only supports `#{name}` in a class body, or on an object assigned `Klass.new`."
        end

        def mixin_message(node, name)
          return if call_args(node).all? { _1.type?(:const, :self) }
          # `str.prepend("x")` and `arr.prepend(0)` are not mixins
          return if node.receiver && !node.receiver.self_type? && !hook_param?(node.receiver)

          "Spinel only supports `#{name}` of a constant module."
        end

        # string evals expand at compile time only as receiverless class/module macros
        def eval_message(node, name)
          if EVALS.include?(name) && call_args(node).any? { !_1.block_pass_type? }
            return if name != :instance_eval && node.receiver.nil?

            return "Spinel does not support `#{name}` with a string; use the block form."
          end
          return if %i[instance_eval instance_exec].include?(name) || !node.block_node&.body&.each_node(:def, :defs)&.any?
          return if node.receiver.nil? || node.receiver.type?(:self, :const) || hook_param?(node.receiver)

          "Spinel cannot define methods on a class held in a variable."
        end

        def new_message(node)
          case node.receiver&.const_type? && node.receiver.short_name
          when :Struct then "Spinel does not support `Struct.new` with a string name; use `Name = Struct.new(...)`." if node.first_argument&.str_type?
          when :Class then subclass_message(node.first_argument) if builtin_class?(node.first_argument)
          end
        end

        def refinement_message(node, name)
          return if node.receiver
          return unless (name == :using) ? node.first_argument&.const_type? : node.block_node

          "Spinel does not support refinements; reopen the class instead."
        end

        def require_message(node)
          return unless node.receiver.nil? || const_receiver?(node, :Kernel)

          feature = node.first_argument
          "Spinel does not provide `require \"#{feature.value}\"`." if feature&.str_type? && unsupported_require?(feature.value)
        end

        # `AllowedRequires` names features the project provides itself, eg. as spin packages
        def unsupported_require?(feature)
          cop_config.fetch("UnsupportedRequires", []).include?(feature) && !cop_config.fetch("AllowedRequires", []).include?(feature)
        end

        # CRuby loads did_you_mean at boot, so no `require` gives its absence away
        def did_you_mean_message
          return if user_class?(:DidYouMean) || required?("did_you_mean")

          "Spinel does not provide `DidYouMean`, which CRuby loads at boot."
        end

        def method_list_message(name)
          "Spinel does not support `#{name}`; list the methods explicitly."
        end

        # `methods` and `respond_to?(name)` work on an object, and `self.respond_to?` at the top level
        def top_level_reflection_message(node, name)
          return if node.receiver || node.each_ancestor(:def, :defs, :class, :module, :sclass).any?
          return if node.each_ancestor(:block).any? { class_body?(_1) || %i[instance_eval instance_exec].include?(_1.send_node.method_name) }

          "Spinel does not support a receiverless `#{name}` at the top level."
        end

        def time_parser_message(name)
          "Spinel does not provide `Time.#{name}`; build the Time from its parts, eg. with `Time.at` or `Time.new`."
        end

        def native_method_message(node)
          return unless node.first_argument&.type?(:sym, :str)

          "Spinel cannot make a Method of the native `#{node.receiver.source}.#{node.first_argument.value}`; call it in a block."
        end

        # `Base64`, `JSON`, `Digest::SHA256`, unless the program defines its own
        def native_function_module?(recv)
          return false unless recv&.const_type?

          root = recv
          root = root.namespace while root.namespace&.const_type?
          NATIVE_FUNCTION_MODULES.include?(root.short_name) && top_level?(root) && !user_class?(root.short_name)
        end

        # `Time.parse`, unless the program defines its own Time
        def builtin_receiver?(node, name)
          const_receiver?(node, name) && top_level?(node.receiver) && !user_class?(name)
        end

        # `if (CONFIG = load)`, `while (LINE = gets)`
        def constant_assignment?(condition) = unparenthesized(condition)&.casgn_type?

        def correct_call(corrector, node)
          return unless direct?(node)

          case node.method_name
          when :method then native_method_block(corrector, node)
          when :slice_after, :slice_before then proc_arg_block(corrector, node)
          end
        end

        # `list.map(&Base64.method(:strict_decode64))` -> `list.map { Base64.strict_decode64(it) }`
        def native_method_block(corrector, node)
          pass = node.parent
          return unless pass&.block_pass_type? && pass.parent&.call_type? && ONE_VALUE_ITERATORS.include?(pass.parent.method_name)

          name = node.first_argument.value.to_s
          param = block_param(node)
          return unless param && name.match?(/\A[a-z_]\w*[?!]?\z/)

          corrector.replace(*block_edit(pass, "{ #{node.receiver.source}.#{name}(#{param}) }"))
        end

        # `it` from Ruby 3.4, else `_1`, which cannot nest in another numbered-parameter block
        def block_param(node)
          return "it" if target_ruby_version >= 3.4

          "_1" unless node.each_ancestor(:numblock).any?
        end

        # `slice_before(->(x) { x.even? })` -> `slice_before { |x| x.even? }`
        def proc_arg_block(corrector, node)
          lambda = node.first_argument
          return unless node.arguments.one? && lambda.type?(:block, :numblock, :itblock) && lambda.lambda_or_proc?
          # `return` / `break` leave a block differently, and a block splats an array over several params
          return if lambda.body&.each_node(:return, :break)&.any? || lambda.argument_list.size > 1

          corrector.replace(*block_edit(lambda, block_literal(lambda)))
        end

        # a lambda or proc as a brace block: `->(x) { x }` / `lambda do |x| x end` -> `{ |x| x }`
        # (braces, since a `do` block would bind to an outer call without parens)
        def block_literal(lambda)
          stabby = lambda.send_node.lambda_literal? && lambda.block_type?
          params = stabby ? lambda.argument_list.map(&:source).join(", ") : ""
          inner = lambda.loc.begin.end.join(lambda.loc.end.begin).source
          "{#{" |#{params}|" unless params.empty?}#{inner}}"
        end

        # the edit turning a call's last argument into a block: `f(a, &b)` -> `f(a) { ... }`
        def block_edit(arg, block)
          call = arg.parent
          kept = call.arguments.take_while { !_1.equal?(arg) }
          args = kept.empty? ? "" : "(#{kept.first.source_range.join(kept.last.source_range).source})"
          finish = call.parenthesized? ? call.loc.end : arg.source_range
          [call.loc.selector.end.join(finish), "#{args} #{block}"]
        end

        # `if (CONFIG = load)` -> `CONFIG = load` ahead of `if CONFIG`
        def hoist_constant(corrector, node)
          return unless statement?(node)

          assignment = unparenthesized(node.condition)
          corrector.replace(node.condition, assignment.source_range.begin.join(assignment.loc.name).source)
          corrector.insert_before(node, "#{assignment.source}\n#{" " * node.source_range.column}")
        end

        # an `if` that starts its own statement, so code can move ahead of it unchanged
        def statement?(node)
          parent = node.parent
          return false if node.elsif?
          return true if parent.nil? || parent.type?(:begin, :kwbegin)

          parent.type?(:def, :defs, :block, :numblock, :itblock, :class, :module, :sclass) && parent.body.equal?(node)
        end

        # `singleton_class.attr_accessor :x` in a class body is a declaration, not an object
        def singleton_class_message(node)
          parent = node.parent
          return if own_singleton_class?(node) && !in_instance_method?(node) && parent&.send_type? && parent.receiver.equal?(node) && !SENDS.include?(parent.method_name)

          "Spinel does not support `singleton_class` as an object."
        end

        def literal_name_message(node, name)
          names = call_args(node).first((name == :alias_method) ? 2 : 1)
          return if names.all? { _1.type?(:sym, :str) }

          "Spinel only supports `#{name}` with a literal name."
        end

        def superclass_message(parent)
          parent = parent.children.first while parent&.begin_type? && parent.children.one?
          return if parent.nil?
          return subclass_message(parent) if builtin_class?(parent)
          return if parent.const_type? || static_superclass?(parent)

          "Spinel only supports a constant superclass."
        end

        # `Struct.new(...)`, `Data.define(...)`, or a blockless `Class.new(Const)`
        def static_superclass?(node)
          return false unless node.send_type? && node.receiver&.const_type?

          case [node.receiver.short_name, node.method_name]
          in [:Struct, :new] | [:Data, :define] then true
          in [:Class, :new] then node.arguments.all?(&:const_type?)
          else false
          end
        end

        # self in a class body, a class constant, or an object Spinel traces to `Klass.new`
        def singleton_target?(node, recv)
          return !in_instance_method?(node) if recv.self_type?

          traceable?(recv) || (recv.const_type? && const_writes(recv).empty?)
        end

        def traceable?(recv)
          return false unless recv.type?(:const, *WRITES.keys)

          values = recv.const_type? ? const_writes(recv) : writes(recv)
          values.one? && constructed?(values.first)
        end

        # `Klass.new(...)`, `Class.new { ... }.new`, or `klass.new` with `klass = Class.new`
        def constructed?(node)
          node&.send_type? && node.method?(:new) && class_value?(node.receiver)
        end

        def class_value?(node)
          node = node.send_node if node&.block_type?
          return !UNTRACEABLE.include?(node.short_name) if node&.const_type?
          return writes(node).one? && class_value?(writes(node).first) if node&.lvar_type?

          const_receiver?(node, :Class) && node.method?(:new)
        end

        # `[:a, :b].each { |n| define_method(n) { ... } }` expands at compile time
        def static_name?(node)
          return false if node.nil?
          return true if node.type?(:sym, :str)
          return literal_loop_var?(node) if node.lvar_type?
          return false unless node.type?(:dsym, :dstr)

          node.children.all? { _1.type?(:str, :sym) || (_1.begin_type? && _1.children.one? && literal_loop_var?(_1.children.first)) }
        end

        def literal_loop_var?(node)
          return false unless node&.lvar_type?

          block = node.each_ancestor(:block).find { |b| b.argument_list.any? { _1.name == node.children.first } }
          return false unless block&.send_node&.method?(:each)

          list = block.send_node.receiver
          list = list.children.first while list&.begin_type? && list.children.one?
          return list.children.all? { _1&.int_type? } if list&.type?(:irange, :erange)

          list&.array_type? && list.values.all? { _1.type?(:sym, :str, :int) }
        end

        # `base` in `def self.included(base)`
        def hook_param?(recv)
          return false unless recv.lvar_type?

          hook = recv.each_ancestor(:def, :defs).first
          hook && HOOKS.include?(hook.method_name) && hook.arguments.first&.name == recv.children.first
        end

        # a receiver other than self: `Klass.include M`, `base.send(:include, M)`
        def foreign_receiver?(node)
          recv = node.receiver
          return false if recv.nil? || recv.self_type? || own_singleton_class?(recv)
          # `str.prepend("x")` and `arr.prepend(0)` are not mixins
          return false if %i[include prepend].include?(call_name(node)) && !recv.const_type? && !module_args?(node)
          # activesupport's IsolatedExecutionState
          return false if %i[Fiber Thread].any? { const_receiver?(node, _1) }

          !(direct?(node) && hook_param?(recv))
        end

        # `binding.local_variable_get(:x)` resolves to a known slot
        def binding_local?(node)
          parent = node.parent
          parent&.send_type? && parent.receiver.equal?(node) && BINDING_LOCALS.include?(parent.method_name) && parent.first_argument&.sym_type?
        end

        # `ObjectSpace.each_object`, `ObjectSpace::WeakMap`; a bare value is fine
        def object_space_use?(node)
          parent = node.parent
          return parent.namespace.equal?(node) if parent&.const_type?

          parent&.send_type? && parent.receiver.equal?(node) && !OBJECT_SPACE_OK.include?(parent.method_name)
        end

        # instance methods of a class run per object; module methods may be class-level macros
        def in_instance_method?(node)
          method = node.each_ancestor(:def, :defs, :block).find { _1.type?(:def, :defs) || class_body?(_1) }
          method&.def_type? && !method.each_ancestor(:class, :module, :sclass).first&.type?(:module, :sclass)
        end

        # `Class.new do ... end` and `klass.class_eval do ... end` bodies are class bodies
        def class_body?(block)
          send = block.send_node
          (send.method?(:new) && (const_receiver?(send, :Class) || const_receiver?(send, :Module))) ||
            %i[class_eval class_exec module_eval module_exec].include?(send.method_name)
        end

        # `Array`, `::Hash` or `Thread::Queue`, unless the program defines its own
        def builtin_class?(node)
          return false unless node&.const_type? && BUILTIN_CLASSES.include?(node.short_name) && !user_class?(node.short_name)

          top_level?(node) || node.namespace.source == "Thread"
        end

        def const_receiver?(node, name)
          recv = node&.receiver
          recv&.const_type? && recv.short_name == name
        end

        def const_writes(const)
          processed_source.ast.each_node(:casgn).select { _1.name == const.short_name }.map(&:expression)
        end

        # `singleton_class` or `self.singleton_class`
        def own_singleton_class?(node)
          node.send_type? && node.method?(:singleton_class) && (node.receiver.nil? || node.receiver.self_type?)
        end

        def proc_arg?(node)
          node&.lambda_or_proc? || (node&.lvar_type? && writes(node).any? { _1&.lambda_or_proc? })
        end

        # `recv.send(:name, *args)` is checked as `recv.name(*args)`
        def sent?(node) = SENDS.include?(node.method_name) && node.first_argument&.sym_type?

        def subclass_message(node)
          "Spinel does not support subclassing `#{node.short_name}`; wrap it in an instance variable."
        end

        # `((x))` -> `x`
        def unparenthesized(node)
          node = node.children.first while node&.begin_type? && node.children.one?
          node
        end

        # one-liners

        def call_args(node) = sent?(node) ? node.arguments.drop(1) : node.arguments
        def call_name(node) = sent?(node) ? node.first_argument.value : node.method_name
        def direct?(node) = !sent?(node)
        def module_args?(node) = call_args(node).any? && call_args(node).all?(&:const_type?)
        def singleton_owner(node) = node.each_ancestor(:class, :module).first
        def unsupported(name) = MESSAGES.fetch(name) { "Spinel does not support `#{name}`." }
      end
    end
  end
end
