# plugin integration for RuboCop

require "lint_roller"

module RuboCop
  module Spinel
    class Plugin < LintRoller::Plugin
      def about
        LintRoller::About.new(
          name: "rubocop-spinel",
          version: VERSION,
          homepage: "https://github.com/gurgeous/rubocop-spinel",
          description: "Custom RuboCop cops for Spinel compatibility."
        )
      end

      def supported?(context) = context.engine == :rubocop

      def rules(_context)
        LintRoller::Rules.new(
          type: :path,
          config_format: :rubocop,
          value: Pathname.new(__dir__).join("../../../config/default.yml")
        )
      end
    end
  end
end
