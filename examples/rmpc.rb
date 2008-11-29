#!/usr/bin/ruby -w

# This is a very simple MPD client that just sends commands to the server
# from the command line
#
# Copyright 2006 Andrew Rader ( bitwise_mcgee AT yahoo.com | http://nymb.us )
#

require 'rubygems'
require 'librmpd'
require 'thread'

if ARGV.length == 0
  puts "Usage: rmpc.rb <command> <command options>"
  puts "\tUse --help for commands / command options"

else
  if ARGV.include?( '--help' ) or ARGV.include?( '-h' )
    puts "Usage: rmpc.rb <command> <command options>"
    puts "\tAvailable Commands / Command Options:\n\n"
    puts "\tcmd\topts\tdescription"
    puts "\tplay\t[pos]\tbegin playback, optionally play song at position pos"
    puts "\tpause\tnone\ttoggle the pause flag"
    puts "\tstop\tnone\tstop playback"
    puts "\tnext\tnone\tplay next in playlist"
    puts "\tprev\tnone\tplay previous in playlist"
    puts "\tvolume\t[vol]\tprint the current volume, or, sets the volume to vol"
    puts "\trepeat\tnone\ttoggle the repeat flag"
    puts "\trandom\tnone\ttoggle the random flag"
    puts "\tstats\tnone\tprint the server stats"
  else
    mpd = MPD.new
    mpd.connect
    case ARGV[0]
    when 'play'
      mpd.play ARGV[1].to_i - 1
    when 'pause'
      mpd.pause = !mpd.paused?
    when 'stop'
      mpd.stop
    when 'next'
      mpd.next
    when 'prev'
      mpd.previous
    when 'volume'
      if ARGV[1].nil?
        puts "Volume: #{mpd.volume}"
      else
        mpd.volume = ARGV[1].to_i
      end
    when 'repeat'
      mpd.repeat = !mpd.repeat?
    when 'random'
      mpd.random = !mpd.random?
    when 'stats'
      hash = mpd.stats
      hash.each_pair do |key, value|
        puts "#{key} => #{value}"
      end
    else
      puts "Unknown Command #{ARGV[0]}"
    end
    mpd.disconnect
  end
end
