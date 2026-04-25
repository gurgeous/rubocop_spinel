# shared test setup

require "amazing_print"
require "minitest/autorun"
require "minitest/hooks"
require "minitest/pride"
require "mocha/minitest"
require "rubocop_spinel"

class Minitest::Test
  include Minitest::Hooks

  protected

  def assert_equal(exp, act, msg = nil)
    # just a hack to workaround the assert_nil warning
    assert(exp == act, message(msg) { diff(exp, act) })
  end
end
