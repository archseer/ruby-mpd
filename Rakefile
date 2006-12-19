require 'rubygems'
Gem::manage_gems
require 'rake/gempackagetask'

spec = Gem::Specification.new do |s|
	s.platform	=	Gem::Platform::RUBY
	s.name			=	"librmpd"
	s.version		=	"0.1.1"
	s.author		=	"Andrew Rader"
	s.email			=	"bitwise_mcgee @nospam@ yahoo.com"
	s.summary		=	"A library for the Music Player Daemon (MPD)"
	s.description = "A library for the Music Player Daemon (MPD)"
	s.files			=	FileList['lib/*.rb', 'data/*.yaml', 'examples/*.rb', 'test/*', 'AUTHORS', 'COPYING'].to_a
	s.require_path	=	"lib"
	s.test_files = Dir.glob('tests/*.rb')
	s.has_rdoc	=	true
	s.extra_rdoc_files	=	['README']
end

Rake::GemPackageTask.new(spec) do |pkg|
	pkg.need_tar = true
end

task :default => "pkg/#{spec.name}-#{spec.version}.gem" do
	puts 'generated latest version'
end
