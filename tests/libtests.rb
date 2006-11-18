#
# Unit tests for librmpd
#
# This uses the included mpdserver.rb test server

require 'rubygems'
require 'librmpd'
load '../lib/mpdserver.rb'
require 'test/unit'

class MPDTester < Test::Unit::TestCase

	def setup
		begin
			@port = 9393
			@server = MPDTestServer.new @port, '../lib/database.yaml'
			@server.start
		rescue Errno::EADDRINUSE
			@port = 9494
			@server = MPDTestServer.new @port, '../lib/database.yaml'
			@server.start
		end
		@mpd = MPD.new 'localhost', @port
	end

	def teardown
		@mpd.disconnect
		@server.stop
	end

	def test_connect
		ret = @mpd.connect
		assert_match /OK MPD [0-9.]*\n/, ret
	end

	def test_connected?
		# test a good connection
		@mpd.connect
		assert @mpd.connected?

		# Test a disconnect
		@server.stop
		assert !@mpd.connected?

		# test a bad connection
		bad = MPD.new 'no-connection', 6600
		assert !bad.connected?
	end

	def test_disconnect
		# test a good connection
		@mpd.connect
		assert @mpd.connected?
		@mpd.disconnect
		assert !@mpd.connected?
		@mpd.disconnect
		assert !@mpd.connected?

		# test a bad connection
		bad = MPD.new 'no-connection'
		bad.disconnect
		assert !bad.connected?
	end

	def test_add
		@mpd.connect
		assert @mpd.connected?

		assert @mpd.add('Shpongle/Are_You_Shpongled/1.Shpongle_Falls.ogg')

		pls = @mpd.playlist
		assert_equal 1, pls.size
		assert_equal 'Shpongle', pls[0].artist
		assert_equal 'Are You Shpongled?', pls[0].album
		assert_equal 'Shpongle Falls', pls[0].title
	end

	def test_clear
		@mpd.connect
		assert @mpd.connected?

		assert @mpd.add('Shpongle')

		pls = @mpd.playlist
		assert_equal 27, pls.size

		assert @mpd.clear

		pls = @mpd.playlist
		assert_equal 0, pls.size
	end

	def test_clearerror
		#TODO
	end

	def test_crossfade
		@mpd.connect

		@mpd.crossfade = 40

		assert_equal 40, @mpd.crossfade
		assert_equal '40', @mpd.status['xfade']

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.crossfade = 20}
		assert_raise(RuntimeError) {@mpd.crossfade}
	end

	def test_current_song
		#TODO
	end

	def test_delete
		#TODO
	end

	def test_deleteid
		#TODO
	end

	def test_find
		#TODO
	end

	def test_kill
		#TODO
	end

	def test_albums
		#TODO
	end

	def test_artists
		#TODO
	end

	def test_list
		#TODO
	end

	def test_directories
		#TODO
	end

	def test_files
		#TODO
	end

	def test_playlists
		#TODO
	end

	def test_songs
		#TODO
	end

	def test_songs_by_artist
		#TODO
	end

	def test_load
		#TODO
	end

	def test_move
		#TODO
	end

	def test_moveid
		#TODO
	end

	def test_next
		@mpd.connect

		@mpd.load 'Astral_Projection_-_Dancing_Galaxy'

		@mpd.play 3

		pos = @mpd.status['song'].to_i

		assert @mpd.next

		assert_equal pos + 1, @mpd.status['song'].to_i

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.next}
	end

	def test_pause
		@mpd.connect
		assert @mpd.connected?

		@mpd.load 'Astral_Projection_-_Dancing_Galaxy'

		assert @mpd.play
		assert @mpd.playing?

		@mpd.pause = true
		assert @mpd.paused?

		@mpd.pause = false
		assert !@mpd.paused?

		assert @mpd.stop
		assert @mpd.stopped?

		@mpd.pause = true
		assert @mpd.stopped?

		assert !@mpd.paused?

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.pause = true}
		assert_raise(RuntimeError) {@mpd.paused?}
	end

	def test_password
		#TODO
	end

	def test_ping
		#TODO
	end

	def test_play
		# test a good connection
		@mpd.connect
		assert @mpd.connected?

		@mpd.load 'Astral_Projection_-_Dancing_Galaxy'

		# test no arguments
		assert @mpd.play

		assert @mpd.playing?

		# test an argument
		assert @mpd.play(2)
		assert @mpd.playing?

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.play}
		assert_raise(RuntimeError) {@mpd.playing?}
	end

	def test_playid
		#TODO
	end

	def test_playlist_version
		#TODO
	end

	def test_playlist
		#TODO
	end

	def test_song_at_pos
		#TODO
	end

	def test_song_with_id
		#TODO
	end

	def test_playlist_changes
		#TODO
	end

	def test_previous
		@mpd.connect

		@mpd.load 'Astral_Projection_-_Dancing_Galaxy'

		@mpd.play 3

		sleep 2

		assert @mpd.playing?

		pos = @mpd.status['song'].to_i

		assert @mpd.previous

		assert_equal pos - 1, @mpd.status['song'].to_i

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.previous}
	end

	def test_random
		@mpd.connect

		@mpd.random = true
		assert @mpd.random?

		@mpd.random = false
		assert !@mpd.random?

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.random = false}
		assert_raise(RuntimeError) {@mpd.random?}
	end

	def test_repeat
		@mpd.connect

		@mpd.repeat = true
		assert @mpd.repeat?

		@mpd.repeat = false
		assert !@mpd.repeat?

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.repeat = false}
		assert_raise(RuntimeError) {@mpd.repeat?}
	end

	def test_rm
		#TODO
	end

	def test_remove_playlist
		#TODO
	end

	def test_save
		#TODO
	end

	def test_search
		#TODO
	end

	def test_seek
		#TODO
	end

	def test_seekid
		#TODO
	end

	def test_volume
		@mpd.connect
		
		vol = @mpd.volume

		@mpd.volume = 30
		assert_equal 30, @mpd.volume

		@mpd.volume = vol
		assert_equal vol, @mpd.volume

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.volume = 10}
		assert_raise(RuntimeError) {@mpd.volume}
	end

	def test_shuffle
		#TODO
	end

	def test_stats
		#TODO
	end

	def test_status
		#TODO
	end

	def test_stop
		@mpd.connect
		assert @mpd.connected?

		@mpd.load 'Astral_Projection_-_Dancing_Galaxy'

		assert @mpd.play
		assert @mpd.playing?

		assert @mpd.stop
		assert @mpd.stopped?

		assert !@mpd.playing?

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.stop}
		assert_raise(RuntimeError) {@mpd.stopped?}
	end

	def test_swap
		#TODO
	end

	def test_swapid
		#TODO
	end

	def test_update
		#TODO
	end

end
