require_relative './_helper'

Parser = Class.new do
  include MPD::Parser
end
Parser.send(:public, *MPD::Parser.private_instance_methods)

class TestParser < MiniTest::Test
  def setup
    @parser = Parser.new
  end

  # Conversions for commands to the server
  def test_convert_bool
    assert_equal @parser.convert_command(:pause, true), 'pause 1'
    assert_equal @parser.convert_command(:pause, false), 'pause 0'
  end

  def test_convert_range
    # inclusive range
    assert_equal @parser.convert_command(:playlistinfo, 1..10), 'playlistinfo 1:11'
    # exclusive range
    assert_equal @parser.convert_command(:playlistinfo, 2...5), 'playlistinfo 2:5'

    # negative means "till end of range"
    assert_equal @parser.convert_command(:playlistinfo, 2...-1), 'playlistinfo 2:'
  end

  def test_convert_escape_whitespace
    assert_equal @parser.convert_command(:lsinfo, '/media/Storage/epic music'), 'lsinfo "/media/Storage/epic music"'
  end

  # Parse replies from server
  def test_parse_empty_listall_command
    assert_equal @parser.parse_response(:listall, ''), {}
  end

  def test_parse_playlist_uint
    assert_equal @parser.parse_key(:playlist, '31'), 31
  end

  def test_parse_playlist_name
    assert_equal @parser.parse_key(:playlist, 'leftover/classics.m3u'), 'leftover/classics.m3u'
  end

end

class TestParsingSongs < MiniTest::Test
  def setup
    spoof_dir = File.expand_path('../socket_recordings',__FILE__)
    @mpd = PlaybackMPD.new spoof_dir
  end
  def test_playlist_songs
    songs = MPD::Playlist.new( @mpd, 'onesong' ).songs
    assert_kind_of Array, songs
    assert_equal 1, songs.length
    assert songs.all?{ |value| value.is_a? MPD::Song }, "Every return value is a Song"
    assert_equal songs.first.track_length, 226

    songs = MPD::Playlist.new( @mpd, 'twosongs' ).songs
    assert_kind_of Array, songs
    assert_equal 2, songs.length
    assert songs.all?{ |value| value.is_a? MPD::Song }, "Every return value is a Song"
    assert_equal songs.first.track_length, 226

    songs = MPD::Playlist.new( @mpd, 'filesonly' ).songs
    assert_kind_of Array, songs
    assert_equal 2, songs.length
    assert songs.all?{ |value| value.is_a? MPD::Song }, "Every return value is a Song"
    assert_equal songs.first.file, "Crash Test Dummies/The Ghosts that Haunt Me/06 The Ghosts That Haunt Me.mp3"
    assert_nil songs.first.track_length
  end
end
