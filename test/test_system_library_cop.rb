# tests for the Spinel system library cop

require_relative "test_helper"

class TestSystemLibraryCop < CopTest
  def test_flags_requires_linking_system_libraries
    configure("Enabled" => true) # disabled by default
    assert_equal [
      "Spinel links `libssl and libcrypto` dynamically for `require \"openssl\"`, so the executable needs it installed wherever it runs.",
    ], messages(<<~RUBY)
      require "openssl"
      require "digest"
    RUBY
    assert_empty messages(<<~RUBY)
      require "openssl" unless RUBY_ENGINE == "spinel"
    RUBY
  end

  private

  def cop_class = RuboCop::Cop::Spinel::SystemLibrary
end
