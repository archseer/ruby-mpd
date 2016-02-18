require '../lib/ruby-mpd'
require './socket_spoof'

class PlaybackMPD < MPD
  def initialize( recordings_directory=nil )
    super()
    @socket = SocketSpoof::Player.new(directory:recordings_directory)
  end
  def last_messages
    @socket.last_messages
  end
end

require 'minitest/autorun'
class TestQueue < MiniTest::Unit::TestCase
  def setup
    @mpd = PlaybackMPD.new 'socket_recordings'
  end

  def test_songs
    songs = @mpd.queue
    assert_equal ["playlistinfo"], @mpd.last_messages
    assert_equal 5, songs.length
    assert songs.all?{ |value| value.is_a? MPD::Song }
    assert_equal [310,226,243,258,347], songs.map(&:track_length)
  end

  def test_command_lists
    ids = @mpd.command_list(:values) do
      clear
      %w[test1.mp3 test\ 2.mp3 test3.mp3].each{ |f| addid(f) }
    end
    assert_equal(
      ["command_list_begin", "clear", "addid test1.mp3", 'addid "test 2.mp3"',
       "addid test3.mp3", "command_list_end"],
      @mpd.last_messages
    )
    assert_equal [107,108,109], ids

    pls = @mpd.command_list(:playlists){ playlists }
    assert_equal(
      ["command_list_begin", "listplaylists", "command_list_end"],
      @mpd.last_messages
    )
    assert_equal(8,pls.length)
    assert pls.all?{ |value| value.is_a? MPD::Playlist }
  end
end