class MPD; end

# Object representation of a song.
#
# If the field doesn't exist or isn't set, nil will be returned
class MPD::Song
  # length in seconds
  attr_reader :file, :title, :time, :artist, :album, :albumartist

  # Source: https://de.wikipedia.org/wiki/Liste_der_ID3v1-Genres
  ID3V1_GENRE_BY_ID = {
    '0'=>"Blues",
    '1'=>"Classic Rock",
    '2'=>"Country",
    '3'=>"Dance",
    '4'=>"Disco",
    '5'=>"Funk",
    '6'=>"Grunge",
    '7'=>"Hip-Hop",
    '8'=>"Jazz",
    '9'=>"Metal",
    '10'=>"New Age",
    '11'=>"Oldies",
    '12'=>"Other",
    '13'=>"Pop",
    '14'=>"Rhythm and Blues",
    '15'=>"Rap",
    '16'=>"Reggae",
    '17'=>"Rock",
    '18'=>"Techno",
    '19'=>"Industrial",
    '20'=>"Alternative",
    '21'=>"Ska",
    '22'=>"Death Metal",
    '23'=>"Pranks",
    '24'=>"Soundtrack",
    '25'=>"Euro-Techno",
    '26'=>"Ambient",
    '27'=>"Trip-Hop",
    '28'=>"Vocal",
    '29'=>"Jazz & Funk",
    '30'=>"Fusion",
    '31'=>"Trance",
    '32'=>"Classical",
    '33'=>"Instrumental",
    '34'=>"Acid",
    '35'=>"House",
    '36'=>"Game",
    '37'=>"Sound Clip",
    '38'=>"Gospel",
    '39'=>"Noise",
    '40'=>"Alternative Rock",
    '41'=>"Bass",
    '42'=>"Soul",
    '43'=>"Punk",
    '44'=>"Space",
    '45'=>"Meditative",
    '46'=>"Instrumental Pop",
    '47'=>"Instrumental Rock",
    '48'=>"Ethnic",
    '49'=>"Gothic",
    '50'=>"Darkwave",
    '51'=>"Techno-Industrial",
    '52'=>"Electronic",
    '53'=>"Pop-Folk",
    '54'=>"Eurodance",
    '55'=>"Dream",
    '56'=>"Southern Rock",
    '57'=>"Comedy",
    '58'=>"Cult",
    '59'=>"Gangsta",
    '60'=>"Top 40",
    '61'=>"Christian Rap",
    '62'=>"Pop/Funk",
    '63'=>"Jungle",
    '64'=>"Native US",
    '65'=>"Cabaret",
    '66'=>"New Wave",
    '67'=>"Psychedelic",
    '68'=>"Rave",
    '69'=>"Showtunes",
    '70'=>"Trailer",
    '71'=>"Lo-Fi",
    '72'=>"Tribal",
    '73'=>"Acid Punk",
    '74'=>"Acid Jazz",
    '75'=>"Polka",
    '76'=>"Retro",
    '77'=>"Musical",
    '78'=>"Rock & Roll",
    '79'=>"Hard Rock",

    # WinAmp additions beyond ID3v1
    '80'=>"Folk",
    '81'=>"Folk-Rock",
    '82'=>"National Folk",
    '83'=>"Swing",
    '84'=>"Fast Fusion",
    '85'=>"Bebop",
    '86'=>"Latin",
    '87'=>"Revival",
    '88'=>"Celtic",
    '89'=>"Bluegrass",
    '90'=>"Avantgarde",
    '91'=>"Gothic Rock",
    '92'=>"Progressive Rock",
    '93'=>"Psychedelic Rock",
    '94'=>"Symphonic Rock",
    '95'=>"Slow Rock",
    '96'=>"Big Band",
    '97'=>"Chorus",
    '98'=>"Easy Listening",
    '99'=>"Acoustic",
    '100'=>"Humour",
    '101'=>"Speech",
    '102'=>"Chanson",
    '103'=>"Opera",
    '104'=>"Chamber Music",
    '105'=>"Sonata",
    '106'=>"Symphony",
    '107'=>"Booty Bass",
    '108'=>"Primus",
    '109'=>"Porn Groove",
    '110'=>"Satire",
    '111'=>"Slow Jam",
    '112'=>"Club",
    '113'=>"Tango",
    '114'=>"Samba",
    '115'=>"Folklore",
    '116'=>"Ballad",
    '117'=>"Power Ballad",
    '118'=>"Rhythmic Soul",
    '119'=>"Freestyle",
    '120'=>"Duet",
    '121'=>"Punk Rock",
    '122'=>"Drum Solo",
    '123'=>"A cappella",
    '124'=>"Euro-House",
    '125'=>"Dance Hall",
    '126'=>"Goa",
    '127'=>"Drum & Bass",
    '128'=>"Club-House",
    '129'=>"Hardcore Techno",
    '130'=>"Terror",
    '131'=>"Indie",
    '132'=>"BritPop",
    '133'=>"Negerpunk",
    '134'=>"Polsk Punk",
    '135'=>"Beat",
    '136'=>"Christian Gangsta Rap",
    '137'=>"Heavy Metal",
    '138'=>"Black Metal",
    '139'=>"Crossover",
    '140'=>"Contemporary Christian",
    '141'=>"Christian Rock",
    '142'=>"Merengue",
    '143'=>"Salsa",
    '144'=>"Thrash Metal",
    '145'=>"Anime",
    '146'=>"Jpop",
    '147'=>"Synthpop",
    '148'=>"Abstract",
    '149'=>"Art Rock",
    '150'=>"Baroque",
    '151'=>"Bhangra",
    '152'=>"Big Beat",
    '153'=>"Breakbeat",
    '154'=>"Chillout",
    '155'=>"Downtempo",
    '156'=>"Dub",
    '157'=>"EBM",
    '158'=>"Eclectic",
    '159'=>"Electro",
    '160'=>"Electroclash",
    '161'=>"Emo",
    '162'=>"Experimental",
    '163'=>"Garage",
    '164'=>"Global",
    '165'=>"IDM",
    '166'=>"Illbient",
    '167'=>"Industro-Goth",
    '168'=>"Jam Band",
    '169'=>"Krautrock",
    '170'=>"Leftfield",
    '171'=>"Lounge",
    '172'=>"Math Rock",
    '173'=>"New Romantic",
    '174'=>"Nu-Breakz",
    '175'=>"Post-Punk",
    '176'=>"Post-Rock",
    '177'=>"Psytrance",
    '178'=>"Shoegaze",
    '179'=>"Space Rock",
    '180'=>"Trop Rock",
    '181'=>"World Music",
    '182'=>"Neoclassical",
    '183'=>"Audiobook",
    '184'=>"Audio Theatre",
    '185'=>"Neue Deutsche Welle",
    '186'=>"Podcast",
    '187'=>"Indie Rock",
    '188'=>"G-Funk",
    '189'=>"Dubstep",
    '190'=>"Garage Rock",
    '191'=>"Psybient"
  }
  private_constant :ID3V1_GENRE_BY_ID

  def initialize(mpd, options)
    @mpd = mpd
    @data = {} # allowed fields are @types + :file
    @time = options.delete(:time) # an array of 2 items where last is time
    @file = options.delete(:file)
    @title = options.delete(:title)
    @artist = options.delete(:artist)
    @album = options.delete(:album)
    @albumartist = options.delete(:albumartist)
    @data.merge! options
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
    @time.first
  end

  def track_length
    @time.last
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
    @comments ||= @mpd.send_command :readcomments, @file
  end

  # All genres for the song.
  #
  # Songs may have multiple genres applied.
  # This method returns an array, which will be empty
  # if the song has no genre information.
  #
  # @return [Array<String>] All genres for the song.
  def genres
    Array(@data[:genre]).map do |genre|
      id = genre[/\A\((\d+)\)\z/,1]
      id && ID3V1_GENRE_BY_ID[id] || genre
    end
  end

  # The first genre for the song.
  #
  # @return [String] if the song has a genre.
  # @return [nil] if the song has no genre information.
  def genre
    genres.first
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

  alias :eql? :==
end
