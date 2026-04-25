# gem metadata

require_relative "lib/rubocop_spinel/version"

Gem::Specification.new do |s|
  s.name = "rubocop-spinel"
  s.version = RubocopSpinel::VERSION
  s.authors = ["gurgeous"]
  s.email = ["amd@gurge.com"]

  s.summary = "Short summary of what the gem does."
  s.homepage = "https://github.com/gurgeous/rubocop-spinel"
  s.license = "MIT"
  s.required_ruby_version = ">= 3.0.0"
  s.metadata = {
    "homepage_uri" => s.homepage,
    "rubygems_mfa_required" => "true",
  }

  # shipped files
  s.files = `git ls-files`.split("\n").grep_v(%r{^(bin|demo|test)/})
  s.require_paths = ["lib"]

  # runtime dependencies
  s.add_dependency "rubocop", ">= 1.84", "< 2.0"
end
