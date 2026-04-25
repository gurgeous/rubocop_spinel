# smoke tests for the gem

class TestRubocopSpinel < Minitest::Test
  def test_loads_default_config
    refute_nil RuboCop::ConfigLoader.default_configuration["Spinel/Unsupported"]
  end

  def test_has_version
    refute_nil RubocopSpinel::VERSION
  end
end
