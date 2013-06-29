require 'time' # required for Time.iso8601

class MPD
  # Parser module, being able to parse messages to and from the MPD daemon format.
  # @todo There are several parser hacks. Time is an array in status and a normal
  #   string in MPD::Song, so we do`@time = options.delete(:time) { [nil] }.first`
  #   to hack the array return. Playlist names are strings, whilst in status it's 
  #   and int, so we parse it as an int if it's parsed as non-zero (if it's 0 it's a string)
  #   and to fix numeric name playlists (123.m3u), we convert the name to_s inside
  #   MPD::Playlist too.
  module Parser
    private

    # Parses the command into MPD format.
    def convert_command(command, *args)
      args.map! do |word|
        if word.is_a?(TrueClass) || word.is_a?(FalseClass)
          word ? '1' : '0' # convert bool to 1 or 0
        elsif word.is_a?(Range)
          if word.end == -1 # negative means to end of range
            "#{word.begin}:"
          else
            "#{word.begin}:#{word.end + (word.exclude_end? ? 0 : 1)}"
          end
        elsif word.is_a?(MPD::Song)
          word.file
        else
          # escape any strings with space (wrap in double quotes)
          word = word.to_s
          word.match(/\s|'/) ? %Q["#{word}"] : word
        end
      end
      return [command, args].join(' ').strip
    end

    INT_KEYS = [
      :song, :artists, :albums, :songs, :uptime, :playtime, :db_playtime, :volume,
      :playlistlength, :xfade, :pos, :id, :date, :track, :disc, :outputid, :mixrampdelay,
      :bitrate, :nextsong, :nextsongid, :songid, :updating_db,
      :musicbrainz_trackid, :musicbrainz_artistid, :musicbrainz_albumid, :musicbrainz_albumartistid
    ]

    SYM_KEYS = [:command, :state, :changed, :replay_gain_mode, :tagtype]
    FLOAT_KEYS = [:mixrampdb, :elapsed]
    BOOL_KEYS = [:repeat, :random, :single, :consume, :outputenabled]


    # Commands, where it makes sense to always explicitly return an array.
    RETURN_ARRAY = [:channels, :outputs, :readmessages, :list, :listall,
      :listallinfo, :find, :search, :listplaylists, :listplaylist, :playlistfind,
      :playlistsearch, :plchanges, :tagtypes, :commands, :notcommands, :urlhandlers,
      :decoders, :listplaylistinfo, :playlistinfo]

    # Parses key-value pairs into correct class.
    def parse_key(key, value)
      if INT_KEYS.include? key
        value.to_i
      elsif FLOAT_KEYS.include? key
        value == 'nan' ? Float::NAN : value.to_f
      elsif BOOL_KEYS.include? key
        value != '0'
      elsif SYM_KEYS.include? key
        value.to_sym
      elsif key == :playlist && !value.to_i.zero?
        # doc states it's an unsigned int, meaning if we get 0,
        # then it's a name string.
        value.to_i
      elsif key == :db_update
        Time.at(value.to_i)
      elsif key == :"last-modified"
        Time.iso8601(value)
      elsif [:time, :audio].include? key
        value.split(':').map(&:to_i)
      else
        value.force_encoding('UTF-8')
      end
    end

    # Parses a single response line into a key-object (value) pair.
    def parse_line(line)
      return nil if line.nil?
      key, value = line.split(/:\s?/, 2)
      key = key.downcase.to_sym
      return key, parse_key(key, value.chomp)
    end

    # This builds a hash out of lines returned from the server,
    # elements parsed into the correct type.
    #
    # The end result is a hash containing the proper key/value pairs
    def build_hash(string)
      return {} if string.nil?

      string.split("\n").each_with_object({}) do |line, hash|
        key, object = parse_line(line)

        # if val appears more than once, make an array of vals.
        if hash.include? key
          hash[key] = Array(hash[key]) # convert to array (http://rubyquicktips.com/post/9618833891/convert-object-to-array)
          hash[key] << object # add new obj to array
        else # val hasn't appeared yet, map it.
          hash[key] = object # map obj to key
        end
      end
    end

    # Converts the response to MPD::Song objects.
    # @return [Array<MPD::Song>] An array of songs.
    def build_songs_list(array)
      return [] if !array.is_a?(Array)
      return array.map {|hash| Song.new(hash) }
    end

    # Remove lines which we don't want.
    def filter_lines(string, filter)
      string.split("\n").reject {|line| line =~ /(#{filter.join('|')}):/}.join("\n")
    end

    # Make chunks from string.
    # @return [Array<String>]
    def make_chunks(string)
      first_key = string.match(/\A(.+?):\s?/)[1]

      chunks = string.split(/\n(?=#{first_key})/)
      chunks.inject([]) do |result, chunk|
        result << chunk.strip
      end
    end

    # Parses the response, determining per-command on what parsing logic
    # to use (build_response vs build a single grouped hash).
    #
    # @return [Array<Hash>, Array<String>, String, Integer] Parsed response.
    def parse_response(command, string)
      # return explicit array if needed
      return RETURN_ARRAY.include?(command) ? [] : true if string == true
      if command == :listall 
        build_hash(string)
      elsif command == :listallinfo
        build_response(command, string, [:directory, :playlist])
      else
        build_response(command, string)
      end
    end

    # Parses the response into appropriate objects (either a single object,
    # or an array of objects or an array of hashes).
    #
    # @return [Array<Hash>, Array<String>, String, Integer] Parsed response.
    def build_response(command, string, filter=nil)
      return [] if string.nil? || !string.is_a?(String)

      # filter lines if filter specified
      string = filter_lines(string,filter) if filter

      chunks = make_chunks(string)
      # if there are any new lines (more than one data piece), it's a hash, else an object.
      is_hash = chunks.any? {|chunk| chunk.include? "\n"}

      list = chunks.inject([]) do |result, chunk|
        result << (is_hash ? build_hash(chunk) : parse_line(chunk)[1]) # parse_line(chunk)[1] is object
      end

      # if list has only one element and not set to explicit array, return it, else return array
      result = (list.length == 1 && !RETURN_ARRAY.include?(command)) ? list.first : list
      return result
    end

  end
end
