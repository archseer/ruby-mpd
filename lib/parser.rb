require 'time' # required for Time.iso8601

class MPD
  # Parser module, being able to parse messages to and from the MPD daemon format. 
  module Parser
    private

    # Parses the command into MPD format.
    def convert_command(command, *args)
      args.map! do |word| 
        if word.is_a?(TrueClass) || word.is_a?(FalseClass)
          word ? '1' : '0' # convert bool to 1 or 0
        elsif word.is_a?(Range)
          if word.end == -1 #negative means to end of range
            "#{word.begin}:"
          else
            "#{word.begin}:#{word.end + (word.exclude_end? ? 0 : 1)}"
          end
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

    # Parses key-value pairs into correct class
    # @todo special parsing of playlist, it's a int in :status and a string in :listplaylists

    def parse_key key, value
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
        # then it's a name string. HAXX! what if playlist name is '123'?
        # @todo HAXX
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

    # Parses a single response line into an object.
    def parse_line(string)
      return nil if string.nil?
      key, value = string.split(': ', 2)
      key = key.downcase.to_sym
      value ||= '' # no nil values please ("album: ")
      return parse_key(key, value.chomp)
    end

    # This builds a hash out of lines returned from the server,
    # elements parsed into the correct type.
    #
    # The end result is a hash containing the proper key/value pairs
    def build_hash(string)
      return {} if string.nil?

      string.split("\n").each_with_object({}) do |line, hash|
        key, value = line.split(': ', 2)
        key = key.downcase.to_sym
        value ||= '' # no nil values please ("album: ")
        
        # if val appears more than once, make an array of vals.
        if hash.include? key
          hash[key] = [hash[key]] if !hash[key].is_a?(Array) # if necessary
          hash[key] << parse_key(key, value.chomp) # add new val to array
        else # val hasn't appeared yet, map it.
          hash[key] = parse_key(key, value.chomp) # map val to key
        end
      end
    end

    # Converts the response to MPD::Song objects.
    # @return [Array<MPD::Song>] An array of songs.
    def build_songs_list(array)
      return [] if !array.is_a?(Array)
      return array.map {|hash| Song.new(hash) }
    end

    # Make chunks from string.
    # @return [Array<String>]
    def make_chunks(string)
      first_key = string.match(/\A(.+?): /)[1]

      chunks = string.split(/\n(?=#{first_key})/)
      chunks.inject([]) do |result, chunk|
        result << chunk.strip
      end
    end

    # Parses the response into appropriate objects (either a single object, 
    # or an array of objects or an array of hashes).
    #
    # @return [Array<Hash>, Array<String>, String, Integer] Parsed response.
    # @todo fix parsing of :listall
    def build_response(string)
      return [] if string.nil? || !string.is_a?(String)

      chunks = make_chunks(string)
      # if there are any new lines (more than one data piece), it's a hash, else an object.
      is_hash = chunks.any? {|chunk| chunk.include? "\n"}

      list = chunks.inject([]) do |result, chunk|
        result << (is_hash ? build_hash(chunk) : parse_line(chunk))
      end

      # if list has only one element, return it, else return array
      result = list.length == 1 ? list.first : list
      return result
    end

    # Parse the response into groups that have the same key (used for file lists,
    # groups together files, directories and playlists).
    # @return [Hash<Array>] A hash of key groups. 
    def build_groups(string)
      return [] if string.nil? || !string.is_a?(String)

      string.split("\n").each_with_object({}) do |line, hash|
        key, value = line.split(': ', 2)
        key = key.downcase.to_sym
        hash[key] ||= []
        hash[key] << parse_key(key, value.chomp) # map val to key
      end
    end

  end
end