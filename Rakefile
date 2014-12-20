require 'rake/testtask'

Rake::TestTask.new(:test) do |test|
  test.verbose = true
end

desc "Open an irb session preloaded with this API"
task :console do
  $:.unshift(File.expand_path('../lib', __FILE__))
  require_relative './lib/ruby-mpd'
  require 'irb'
  ARGV.clear
  IRB.start
end

task :default => :test
