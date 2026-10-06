# flag requires that make a Spinel executable depend on a system shared library

module RuboCop
  module Cop
    module Spinel
      class SystemLibrary < Base
        include Support

        RESTRICT_ON_SEND = %i[require].freeze

        def on_send(node)
          return unless node.receiver.nil? || const_named?(node.receiver, :Kernel)

          feature = node.first_argument
          library = feature&.str_type? && cop_config.fetch("Libraries", {})[feature.value]
          return unless library

          flag(node, "Spinel links `#{library}` dynamically for `require \"#{feature.value}\"`, so the executable needs it installed wherever it runs.")
        end
      end
    end
  end
end
