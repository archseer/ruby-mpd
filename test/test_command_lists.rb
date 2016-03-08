require_relative './_helper'

class TestQueue < MiniTest::Unit::TestCase
  def setup
    spoof_dir = File.expand_path('../socket_recordings',__FILE__)
    @mpd = PlaybackMPD.new spoof_dir
  end

  def test_songs
    songs = @mpd.queue
    assert_equal ["playlistinfo"], @mpd.last_messages
    assert_equal 5, songs.length
    assert songs.all?{ |value| value.is_a? MPD::Song }
    assert_equal [310,226,243,258,347], songs.map(&:track_length)
  end

  def test_command_list_ids
    clear_and_add = proc{
      clear
      %w[test1.mp3 test\ 2.mp3 test3.mp3].each{ |f| addid(f) }
    }

    result = @mpd.command_list(&clear_and_add)
    assert_nil result
    assert_equal(
      ['command_list_begin','clear','addid test1.mp3','addid "test 2.mp3"','addid test3.mp3','command_list_end'],
      @mpd.last_messages,
      "command list must send commands even if no result is desired"
    )

    ids = @mpd.command_list(results:true,&clear_and_add)
    assert_equal([107,108,109], ids)

    id = @mpd.command_list(results:true){ addid 'test1.mp3' }
    assert_equal([107], id, "single command produces single-valued array")
  end

  def test_command_list_playlists
    assert_nil @mpd.command_list{ playlists }
    assert_equal(
      %w[command_list_begin listplaylists command_list_end],
      @mpd.last_messages,
      "command list must send commands even if no result is desired"
    )

    lists = @mpd.command_list(results:true){ playlists }.first
    assert_equal(8,lists.length)
    lists.each{ |value| assert_kind_of MPD::Playlist, value, ":playlists should only return playlists"  }
    assert lists.any?{ |list| list.name=="Thump" }, "one of the playlists should be named 'Thump'"

    songs = @mpd.command_list(results:true) do
      temp = MPD::Playlist.new(@mpd,'temp')
      temp.clear
      temp.add 'song2.mp3'
      temp.add 'dummy.mp3'
      temp.add 'song1.mp3'
      temp.add 'song3.mp3'
      temp.delete 1
      temp.move 1, 0
      temp.songs
      temp.destroy
    end
    assert_kind_of Array, songs, "The command list returns an array"
    assert_equal 1, songs.length, "Only the `songs` command should produce results"
    songs = songs.first
    assert_equal 3, songs.length, "There are three songs in the result"
    assert songs.all?{ |value| value.is_a? MPD::Song }, "Every return value is a song"
  end

  def test_command_list_songs
    twogenres = proc{ where(genre:'alt'); where(genre:'trance') }
    assert_nil @mpd.command_list(&twogenres)
    assert_equal(
      ['command_list_begin','search genre alt','search genre trance','command_list_end'],
      @mpd.last_messages,
      "command list must send commands even if no result is desired"
    )

    result = @mpd.command_list(results:true,&twogenres)
    assert_kind_of Array, result, "command_list with results always returns an array"
    assert_equal 2, result.size, "two commands yield two results"
    assert_kind_of Array, result[0], "where always returns an array"
    assert_kind_of Array, result[1], "where always returns an array"
    assert_equal 5, result.flatten.size, "there are 5 songs total in the result set"
    result.flatten.each{ |v| assert_kind_of MPD::Song, v, "all results are songs" }
  end

  def test_command_list_song
    onegenre = proc{ where genre:'trance' }
    assert_nil @mpd.command_list(&onegenre)
    assert_equal(
      ['command_list_begin','search genre trance','command_list_end'],
      @mpd.last_messages,
      "command list must send commands even if no result is desired"
    )

    result = @mpd.command_list(results:true,&onegenre)
    assert_kind_of Array, result, "command_list with results always returns an array"
    assert_equal 1, result.size, "one command yields one result"
    assert_kind_of Array, result.first, "`where` returns an array, even if only one value"
    assert_equal 1, result.first.size, "there is 1 song in the result set"
    result.first.each{ |v| assert_kind_of MPD::Song, v, "all results are songs" }
  end

end