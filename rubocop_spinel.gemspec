# gem metadata

require_relative "lib/rubocop/spinel/version"

Gem::Specification.new do |s|
  s.name = "rubocop_spinel"
  s.version = RuboCop::Spinel::VERSION
  s.authors = ["gurgeous"]
  s.email = ["amd@gurge.com"]

  s.summary = "Custom RuboCop cops for Spinel compatibility."
  s.homepage = "https://github.com/gurgeous/rubocop_spinel"
  s.license = "MIT"
  s.required_ruby_version = ">= 3.0.0"
  s.metadata = {
    "default_lint_roller_plugin" => "RuboCop::Spinel::Plugin",
    "homepage_uri" => s.homepage,
    "rubygems_mfa_required" => "true",
  }

  # shipped files
  s.files = `git ls-files`.split("\n").grep_v(%r{^(bin|demo|test)/})
  s.require_paths = ["lib"]

  # runtime dependencies
  s.add_dependency "lint_roller", "~> 1.1"
  s.add_dependency "rubocop", ">= 1.84", "< 2.0"
end
