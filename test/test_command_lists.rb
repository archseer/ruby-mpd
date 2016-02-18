require_relative '../lib/ruby-mpd'
require_relative './socket_spoof'
require 'minitest/autorun'

class PlaybackMPD < MPD
  def initialize( recordings_directory=nil )
    super()
    @socket = SocketSpoof::Player.new(directory:recordings_directory)
  end
  def last_messages
    @socket.last_messages
  end
end

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

    ids = @mpd.command_list(:hash,&clear_and_add)
    assert_equal({id:[107,108,109]}, ids)

    ids = @mpd.command_list(:hashes,&clear_and_add)
    assert_equal([{id:107},{id:108},{id:109}], ids)

    ids = @mpd.command_list(:values,&clear_and_add)
    assert_equal([107,108,109], ids)

    songs = @mpd.command_list(:songs,&clear_and_add)
    assert_equal([], songs, "no songs should be created from invalid data")

    lists = @mpd.command_list(:playlists,&clear_and_add)
    assert_equal([], lists, "no playlists should be created from invalid data")
  end

  def test_command_list_playlists
    assert_nil @mpd.command_list{ playlists }
    assert_equal(
      %w[command_list_begin listplaylists command_list_end],
      @mpd.last_messages,
      "command list must send commands even if no result is desired"
    )

    assert_equal(
      {
        playlist:["Mix Rock Alt Electric", "SNBRN", "Enya-esque", "RecentNice", "Dancetown", "Piano", "Thump", "Smooth Town"],
        :"last-modified" => [
          Time.iso8601('2015-11-23T15:58:51Z'), Time.iso8601('2016-01-26T00:25:52Z'), Time.iso8601('2015-11-18T16:19:12Z'),
          Time.iso8601('2015-12-01T15:52:38Z'), Time.iso8601('2015-11-18T16:19:26Z'), Time.iso8601('2015-11-18T16:17:13Z'),
          Time.iso8601('2015-11-20T15:32:30Z'), Time.iso8601('2015-11-20T15:54:49Z'),
        ]
      },
      @mpd.command_list(:hash){ playlists }
    )

    assert_equal(
      [
        { playlist: "Mix Rock Alt Electric", :"last-modified" => Time.iso8601('2015-11-23T15:58:51Z') },
        { playlist: "SNBRN", :"last-modified" => Time.iso8601('2016-01-26T00:25:52Z') },
        { playlist: "Enya-esque", :"last-modified" => Time.iso8601('2015-11-18T16:19:12Z') },
        { playlist: "RecentNice", :"last-modified" => Time.iso8601('2015-12-01T15:52:38Z') },
        { playlist: "Dancetown", :"last-modified" => Time.iso8601('2015-11-18T16:19:26Z') },
        { playlist: "Piano", :"last-modified" => Time.iso8601('2015-11-18T16:17:13Z') },
        { playlist: "Thump", :"last-modified" => Time.iso8601('2015-11-20T15:32:30Z') },
        { playlist: "Smooth Town", :"last-modified" => Time.iso8601('2015-11-20T15:54:49Z') },
      ],
      @mpd.command_list(:hashes){ playlists }
    )

    assert_equal(
      [
        "Mix Rock Alt Electric", Time.iso8601('2015-11-23T15:58:51Z'),
        "SNBRN", Time.iso8601('2016-01-26T00:25:52Z'),
        "Enya-esque", Time.iso8601('2015-11-18T16:19:12Z'),
        "RecentNice", Time.iso8601('2015-12-01T15:52:38Z'),
        "Dancetown", Time.iso8601('2015-11-18T16:19:26Z'),
        "Piano", Time.iso8601('2015-11-18T16:17:13Z'),
        "Thump", Time.iso8601('2015-11-20T15:32:30Z'),
        "Smooth Town", Time.iso8601('2015-11-20T15:54:49Z'),
      ],
      @mpd.command_list(:values){ playlists }
    )

    assert_equal( [], @mpd.command_list(:songs){ playlists } )

    lists = @mpd.command_list(:playlists){ playlists }
    assert_equal(8,lists.length)
    lists.each{ |value| assert_kind_of MPD::Playlist, value, ":playlists should only return playlists"  }
    assert lists.any?{ |list| list.name=="Thump" }, "one of the playlists should be named 'Thump'"
  end

  def test_command_list_songs
    twogenres = proc{ where(genre:'alt'); where(genre:'trance') }
    assert_nil @mpd.command_list(&twogenres)
    assert_equal(
      ['command_list_begin','search genre alt','search genre trance','command_list_end'],
      @mpd.last_messages,
      "command list must send commands even if no result is desired"
    )

    result = @mpd.command_list(:hash,&twogenres)
    assert_kind_of Hash, result, ":hash style always returns a hash"
    assert_equal 12, result.size, "there are 12 distinct value types in this song set"
    result.values.each do |v|
      assert_kind_of Array, v, "all hash keys are arrays"
      assert_equal 5, v.length, "there are 5 values for each hash key"
    end
    assert_equal [5,6,2,7,2], result[:track]

    result = @mpd.command_list(:hashes,&twogenres)
    assert_kind_of Array, result, ":hashes style always returns an array"
    assert_equal 5, result.size, "there are 5 hash clumps returned"
    result.each{ |h| assert_equal 12, h.length, "every hash should have 12 values" }

    result = @mpd.command_list(:values,&twogenres)
    assert_kind_of Array, result, ":values style always returns an array"
    assert_equal 60, result.size, "there are 60 individual values in the result set"

    result = @mpd.command_list(:songs,&twogenres)
    assert_kind_of Array, result, ":songs style always returns an array"
    assert_equal 5, result.size, "there are 5 songs in the result set"
    result.each{ |v| assert_kind_of MPD::Song, v, "all results are songs" }

    result = @mpd.command_list(:playlists,&twogenres)
    assert_kind_of Array, result, ":playlists style always returns an array"
    assert_empty result, "there are no playlists in the result set"
  end

  def test_command_list_song
    onegenre = proc{ where genre:'trance' }
    assert_nil @mpd.command_list(&onegenre)
    assert_equal(
      ['command_list_begin','search genre trance','command_list_end'],
      @mpd.last_messages,
      "command list must send commands even if no result is desired"
    )

    result = @mpd.command_list(:hash,&onegenre)
    assert_kind_of Hash, result, ":hash style always returns a hash"
    assert_equal 12, result.size, "there are 12 distinct value types in this song set"
    assert_equal "Morphine", result[:title]

    result = @mpd.command_list(:hashes,&onegenre)
    assert_kind_of Array, result, ":hashes style always returns an array"
    assert_equal 1, result.size, "there is one hash returned"
    result.each{ |h| assert_equal 12, h.length, "every hash should have 12 values" }

    result = @mpd.command_list(:values,&onegenre)
    assert_kind_of Array, result, ":values style always returns an array"
    assert_equal 12, result.size, "there are 12 individual values in the result set"

    result = @mpd.command_list(:songs,&onegenre)
    assert_kind_of Array, result, ":songs style always returns an array"
    assert_equal 1, result.size, "there is 1 song in the result set"
    result.each{ |v| assert_kind_of MPD::Song, v, "all results are songs" }

    result = @mpd.command_list(:playlists,&onegenre)
    assert_kind_of Array, result, ":playlists style always returns an array"
    assert_empty result, "there are no playlists in the result set"
  end

end