#!/usr/bin/ruby -w

#
# This is a very simple MPD client that just spews changes on the server
# out to the console (much like tail works on normal files)
#
# Copyright 2006 Andrew Rader ( bitwise_mcgee AT yahoo.com | http://nymb.us )
#

require 'rubygems'
require 'librmpd'
require 'thread'

class TailMPC

  def initialize( time_cb = false )
    @mpd = MPD.new

    @mpd.register_callback( self.method('playlist_cb'), MPD::PLAYLIST_CALLBACK )
    @mpd.register_callback( self.method('song_cb'), MPD::CURRENT_SONG_CALLBACK )
    @mpd.register_callback( self.method('state_cb'), MPD::STATE_CALLBACK )
    @mpd.register_callback( self.method('time_cb'), MPD::TIME_CALLBACK ) if time_cb
    @mpd.register_callback( self.method('vol_cb'), MPD::VOLUME_CALLBACK )
    @mpd.register_callback( self.method('repeat_cb'), MPD::REPEAT_CALLBACK )
    @mpd.register_callback( self.method('random_cb'), MPD::RANDOM_CALLBACK )
    @mpd.register_callback( self.method('pls_length_cb'), MPD::PLAYLIST_LENGTH_CALLBACK )
    @mpd.register_callback( self.method('xfade_cb'), MPD::CROSSFADE_CALLBACK )
    @mpd.register_callback( self.method('songid_cb'), MPD::CURRENT_SONGID_CALLBACK )
    @mpd.register_callback( self.method('bitrate_cb'), MPD::BITRATE_CALLBACK )
    @mpd.register_callback( self.method('audio_cb'), MPD::AUDIO_CALLBACK )
    @mpd.register_callback( self.method('connection_cb'), MPD::CONNECTION_CALLBACK )
  end

  def start
    puts "Starting TailMPC - Press Ctrl-D to quit\n\n"
    @mpd.connect true
    t = Thread.new do
      gets
    end

    t.join
  end

  def stop
    puts "Shutting Down TailMPC"
    @mpd.disconnect true
  end

  def time_cb( elapsed, total )
    el_min = elapsed / 60
    el_sec = elapsed % 60

    elapsed = "#{el_min}:#{el_sec}"

    tot_min = total / 60
    tot_sec = total % 60

    total = "#{tot_min}:#{tot_sec}"
    puts "Time: #{elapsed} / #{total}"
  end

  def state_cb( newstate )
    puts "State: #{newstate}"
  end

  def song_cb( current )
    if not current.nil?
      puts "Current Song: \n\tID: #{current.songid}\n\tPosition: #{current.pos}\n\tFile: #{current.file}\n\tArtist: #{current.artist}\n\tTitle: #{current.title}"
    else
      puts "Curent Song: nil"
    end
  end

  def playlist_cb( pls )
    puts "Playlist: Version ##{pls}"
  end

  def vol_cb( vol )
    puts "Volume: #{vol}%"
  end

  def repeat_cb( rep )
    puts(rep ? 'Repeat: On' : 'Repeat: Off')
  end

  def random_cb( ran )
    puts(ran ? 'Random: On' : 'Random: Off')
  end

  def pls_length_cb( len )
    puts "Playlist Length: #{len}"
  end

  def xfade_cb( xfade )
    puts "Crossfade: #{xfade}"
  end

  def songid_cb( id )
    puts "Current Song ID: #{id}"
  end

  def bitrate_cb( rate )
    puts "Bitrate: #{rate}"
  end

  def audio_cb( sample, bits, channels )
    puts "Audio:\n\tSample Rate: #{sample}\n\tBits: #{bits}\n\tChannels: #{channels}"
  end

  def connection_cb( connected )
    puts( connected ? 'Connected' : 'Disconnected' )
  end
end

client = TailMPC.new #true # Uncomment the true to enable the time callback

client.start
