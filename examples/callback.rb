#!/usr/bin/env ruby

$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/../lib")
require 'ruby-mpd'
require 'pry-byebug'

mpd = MPD.new('jukebox.local', 6600, callbacks: true)

mpd.on :volume do |v|
  puts "volume changed: #{v}"
end

mpd.on :song do |v|
  puts "song changed: #{v.title}" unless v.nil?
end

mpd.on :playlistlength do |v|
  puts "playlist changed: #{v}"
end

puts "connecting..."
mpd.connect

if mpd.connected?
  puts "connected!"
  sleep
end
