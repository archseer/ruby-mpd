require 'hashie/mash'

class MPD; end

# Object representation of a song.
#
# If the field doesn't exist or isn't set, nil will be returned
class MPD::Song < Hashie::Mash

  # allowed fields are @types + :file
  def initialize(mpd, data)
    @mpd = mpd
    super data
  end

  # Two songs are the same when they share the same hash.
  def ==(another)
    to_h == another.to_h
  end

  def to_h
    {
      time: @time,
      file: @file,
      title: @title,
      artist: @artist,
      album: @album,
      albumartist: @albumartist
    }.merge(@data)
  end

  def elapsed
    time.first
  end

  def track_length
    time.last
  end

  # @return [String] A formatted representation of the song length ("1:02")
  def length
    return '--:--' if track_length.nil?
    "#{track_length / 60}:#{"%02d" % (track_length % 60)}"
  end

  # Retrieve "comments" metadata from a file and cache it in the object.
  #
  # @return [Hash] Key value pairs from "comments" metadata on a file.
  # @return [Boolean] True if comments are empty
  def comments
    @comments ||= @mpd.send_command :readcomments, file
  end

  alias :eql? :==
end
