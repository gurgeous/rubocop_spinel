# smoke tests for the gem

class TestRubocopSpinel < Minitest::Test
  def test_exposes_plugin
    assert_equal "rubocop-spinel", RuboCop::Spinel::Plugin.new.about.name
  end

  def test_has_version
    refute_nil RuboCop::Spinel::VERSION
  end
end
