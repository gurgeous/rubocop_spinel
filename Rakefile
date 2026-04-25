require "bundler"
require "rake/testtask"

Rake::TestTask.new do
  files = ARGV.grep(%r{^test/.*\.rb$}).sort
  _1.ruby_opts = ["-W0", "-r#{File.realpath("test/test_helper.rb")}"]
  _1.test_files = files.empty? ? FileList["test/**/test_*.rb"] : files
end
task default: :test
