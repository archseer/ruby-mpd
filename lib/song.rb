class MPD; end

# This class is a glorified Hash used to represent a song.
#
# If the field doesn't exist or isn't set, nil will be returned
class MPD::Song
  def initialize(options)
    @data = {}

    @length = options.delete(:time)
    @data.merge! options
  end

  # Two songs are the same when they are the same file.
  def ==(another)
    self.file == another.file
  end

  def time
    return "#{(@length / 60)}:#{"%02d" % (@length % 60)}"
  end

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