class MPD; end

# Object representation of a song.
#
# If the field doesn't exist or isn't set, nil will be returned
class MPD::Song
  # length in seconds
  attr_reader :file, :title, :time, :artist, :album, :albumartist

  def initialize(mpd, options)
    @mpd = mpd
    @data = {} # allowed fields are @types + :file
    @time = options.delete(:time) { [nil] }.first # HAXX for array return
    @file = options.delete(:file)
    @title = options.delete(:title)
    @artist = options.delete(:artist)
    @album = options.delete(:album)
    @albumartist = options.delete(:albumartist)
    @data.merge! options
  end

  # Two songs are the same when they are the same file.
  def ==(another)
    self.class == another.class && self.file == another.file
  end

  # @return [String] A formatted representation of the song length ("1:02")
  def length
    return '--:--' if @time.nil?
    "#{@time / 60}:#{"%02d" % (@time % 60)}"
  end
 
  # Retrieve "comments" metadata from a file and cache it in the object.
  #
  # @return [Hash] Key value pairs from "comments" metadata on a file.
  # @return [Boolean] True if comments are empty
  def comments
      @comments ||= @mpd.send_command :readcomments, @file
  end

  # Pass any unknown calls over to the data hash.
  def method_missing(m, *a)
    key = m #.to_s
    if key =~ /=$/
      @data[$`] = a[0]
    elsif a.empty?
      @data[key]
    else
      raise NoMethodError, "#{m}"
    end
  end
end
