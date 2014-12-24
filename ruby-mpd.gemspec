# -*- encoding: utf-8 -*-
require_relative "./lib/ruby-mpd/version"

Gem::Specification.new do |s|
  s.platform      = Gem::Platform::RUBY
  s.name          = 'ruby-mpd'
  s.version       = MPD::VERSION
  s.homepage      = 'https://github.com/archSeer/ruby-mpd'
  s.license       = 'GPL-2'
  s.authors       = ["Blaž Hrastnik"]
  s.email         = ['speed.the.bboy@gmail.com']
  s.summary       = "Modern client library for MPD"
  s.description   = "A powerful, modern and feature complete library for the Music Player Daemon."

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
