require "bundler/gem_tasks"
require 'rake/testtask'

Rake::TestTask.new(:test) do |test|
  test.verbose = true
end

desc "Open an irb session preloaded with this API"
task :console do
  require 'ruby-mpd'
  require 'irb'
  ARGV.clear
  IRB.start
end

task :default => :test
