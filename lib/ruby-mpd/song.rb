class MPD; end

# Object representation of a song.
#
# If the field doesn't exist or isn't set, nil will be returned
class MPD::Song
  # length in seconds
  attr_reader :file, :title, :time, :artist, :album, :albumartist

  def initialize(options)
    @data = {} # allowed fields are @types + :file
    @time = options.delete(:time) { [nil] }.first #HAXX for array return
    @file = options.delete(:file)
    @title = options.delete(:title)
    @artist = options.delete(:artist)
    @album = options.delete(:album)
    @albumartist = options.delete(:albumartist)
    @data.merge! options
  end

  # Two songs are the same when they are the same file.
  def ==(another)
    self.file == another.file
  end

  # @return [String] A formatted representation of the song length ("1:02")
  def length
    if @time.nil?
      '--:--'
    else
      "#{(@time / 60)}:#{"%02d" % (@time % 60)}"
    end
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
