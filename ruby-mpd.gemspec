# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ruby-mpd/version'

Gem::Specification.new do |spec|
  spec.name          = "ruby-mpd"
  spec.version       = MPD::VERSION
  spec.authors       = ["Blaž Hrastnik"]
  spec.email         = ["blaz@mxxn.io"]

  spec.summary       = "Modern client library for MPD"
  spec.description   = "A powerful, modern and feature complete library for the Music Player Daemon"
  spec.homepage      = "https://github.com/archSeer/ruby-mpd"
  spec.license       = "GPL-2"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(spec|features)/}) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.1"
end
