#
# Unit tests for librmpd test server
#
# This tests the MPDTestServer class

#require 'rubygems'
#require 'librmpd'
load '../lib/mpdserver.rb'
require 'test/unit'
require 'socket'

class MPDTester < Test::Unit::TestCase

	def setup
		begin
			@port = 9393
			@mpd = MPDTestServer.new @port, '../lib/database.yaml'
			@mpd.start
			@sock = TCPSocket.new 'localhost', @port
		rescue Errno::EADDRINUSE
			@port = 9494
			@mpd = MPDTestServer.new @port, '../lib/database.yaml'
			@mpd.start
			@sock = TCPSocket.new 'localhost', @port
		end
	end

	def teardown
		@mpd.stop
	end

	def get_response
		msg = ''
		reading = true
		error = nil
		while reading
			line = @sock.gets
			case line
				when "OK\n"
					reading = false;
				when /^ACK/
					error = line
					reading = false;
				else
					msg += line
			end
		end

		if error.nil?
			return true if msg.empty?
			return msg
		else
			raise error.gsub( /^ACK \[(\d+)\@(\d+)\] \{(.+)\} (.+)$/, 'MPD Error #\1: \3: \4')
		end
  end

	def test_connect
		assert_equal "OK MPD 0.11.5\n", @sock.gets
	end

	def test_add
		@sock.gets

		# Add w/o args (Adds All Songs)
		@sock.puts 'add'
		assert_equal "OK\n", @sock.gets

		@sock.puts 'playlist'
		reply = get_response
		songs = reply.split "\n"
		assert_equal 46, songs.length

		@sock.puts 'clear'
		assert_equal "OK\n", @sock.gets

		# Add a dir
		@sock.puts 'add Shpongle'
		assert_equal "OK\n", @sock.gets

		@sock.puts 'playlist'
		reply = get_response
		songs = reply.split "\n"
		assert_equal 27, songs.length

		@sock.puts 'clear'
		assert_equal "OK\n", @sock.gets

		@sock.puts 'add Shpongle/Are_You_Shpongled'
		assert_equal "OK\n", @sock.gets

		@sock.puts 'playlist'
		reply = get_response
		songs = reply.split "\n"
		assert_equal 7, songs.length

		@sock.puts 'clear'
		assert_equal "OK\n", @sock.gets

		# Add a song
		@sock.puts 'add Shpongle/Are_You_Shpongled/1.Shpongle_Falls.ogg'
		assert_equal "OK\n", @sock.gets

		@sock.puts 'playlist'
		reply = get_response
		songs = reply.split "\n"
		assert_equal 1, songs.length
		assert_equal '0: Shpongle/Are_You_Shpongled/1.Shpongle_Falls.ogg', songs[0]

		# Add a non existant item
		@sock.puts 'add ABOMINATION'
		assert_equal "ACK [50@0] {add} directory or file not found\n", @sock.gets
	end

	def test_clear
		@sock.gets

		@sock.puts 'add'
		assert_equal "OK\n", @sock.gets

		@sock.puts 'playlist'
		reply = get_response
		songs = reply.split "\n"
		assert_equal 46, songs.length

		@sock.puts 'clear'
		assert_equal "OK\n", @sock.gets

		@sock.puts 'playlist'
		assert_equal "OK\n", @sock.gets

		# Test improper args
		@sock.puts 'clear blah'
		assert_equal "ACK [2@0] {clear} wrong number of arguments for \"clear\"\n", @sock.gets
	end

	def test_clearerror
		# TODO
	end

	def test_close
		@sock.gets

		# Test improper args
		@sock.puts 'close blah'
		assert_raises(Errno::EPIPE) { @sock.puts 'data' }

		@sock = TCPSocket.new 'localhost', @port
		@sock.puts 'close'
		assert_raises(Errno::EPIPE) { @sock.puts 'data' }

	end

	def test_crossfade
		@sock.gets

		# Test no args
		@sock.puts 'crossfade'
		assert_equal "ACK [2@0] {crossfade} wrong number of arguments for \"crossfade\"\n", @sock.gets

		# Test not a number arg
		@sock.puts 'crossfade a'
		assert_equal "ACK [2@0] {crossfade} \"a\" is not a integer >= 0\n", @sock.gets

		# Test arg < 0
		@sock.puts 'crossfade -1'
		assert_equal "ACK [2@0] {crossfade} \"-1\" is not a integer >= 0\n", @sock.gets

		# Test correct arg
		@sock.puts 'crossfade 10'
		assert_equal "OK\n", @sock.gets

		@sock.puts 'status'
		reply = get_response
		crossfade = reply.gsub( /.*\nxfade: (.*)\n.*/,'\1' ).to_i
		assert_not_equal 49, crossfade

		@sock.puts 'crossfade 49'
		assert_equal "OK\n", @sock.gets

		@sock.puts 'status'
		reply = get_response
		xfade = reply.gsub( /.*\nxfade: (.*)\n.*/,'\1' ).to_i
		assert_equal 49, xfade
	end
end
