require_relative 'song'

# TODO:
# 0.14
# * commands:
#  - "addid" takes optional second argument to specify position
# 0.15
# * commands:
#  - "playlistinfo" and "move" supports a range now
#  - added "sticker database", command "sticker", which allows clients
#     to implement features like "song rating"
# * protocol:
#  - added the "findadd" command
#  - range support for "delete"
#  - allow changing replay gain mode on-the-fly
#  - omitting the range end is possible

# ver 0.17 (2012/06/27)
# * protocol:
#  - support client-to-client communication
#  - add range parameter to command "load"
#  - new commands "searchadd", "searchaddpl"

# @!macro [new] returnraise
#   @return [Boolean] returns true if successful.
#   @raise [RuntimeError] if the command failed.

class MPD

  require 'socket'
  require 'thread'

  class MPDError < StandardError; end

  # The version of the MPD protocol the server is using.
  attr_reader :version
 
  # Initialize an MPD object with the specified hostname and port
  # When called without arguments, 'localhost' and 6600 are used
  def initialize(hostname = 'localhost', port = 6600)
    @hostname = hostname
    @port = port
    @socket = nil
    @version = nil
    @stop_cb_thread = false
    @mutex = Mutex.new
    @cb_thread = nil
    @callbacks = {}
  end

  # This will register a block callback that will trigger whenever
  # that  specific event happens.
  #
  #   mpd.on :volume do |volume|
  #     puts "Volume was set to #{volume}"!
  #   end
  #
  # You can also define separate methods or Procs and whatnot,
  # just pass them in as a parameter.
  #
  #  method = Proc.new {|volume| puts "Volume was set to #{volume}"! }
  #  mpd.on :volume, &method
  #
  def on(event, &block)
    @callbacks[event] ||= []
    @callbacks[event].push block
  end

  # Triggers an event, running it's callbacks.
  # @param [Symbol] event The event that happened.
  def emit(event, *args)
    p "#{event} was triggered!"
    @callbacks[event] ||= []
    @callbacks[event].each do |cb|
      cb.call *args
    end
  end

  # Connect to the daemon.
  #
  # When called without any arguments, this will just connect to the server
  # and wait for your commands.
  #
  # When called with true as an argument, this will enable callbacks by starting
  # a seperate polling thread, which will also automatically reconnect if disconnected 
  # for whatever reason.
  #
  # connect will return true if successful, otherwise an error will be raised
  #
  # @raise [RuntimeError] If connect is called on an already connected instance.
  def connect(callbacks = false)
    raise MPDError, 'Already Connected!' if self.connected?

    @socket = File.exists?(@hostname) ? UNIXSocket.new(@hostname) : TCPSocket.new(@hostname, @port)
    @version = @socket.gets.chomp.gsub('OK MPD ', '') # Read the version

    if callbacks and (@cb_thread.nil? or !@cb_thread.alive?)
      @stop_cb_thread = false
      @cb_thread = Thread.new(self) { |mpd|
        old_status = {}
        connected = ''
        while !@stop_cb_thread
          status = mpd.status rescue {}
          c = mpd.connected?

          if connected != c
            connected = c
            emit(:connection, connected)
          end

          status[:time] = [nil, nil] if !status[:time] # elapsed, total
          status[:audio] = [nil, nil, nil] if !status[:audio] # samp, bits, chans

          status.each do |key, val|
            if key == :song
              emit(:song, mpd.current_song) if status[:song] != old_status[:song]
            else # convert arrays to splat arguments
              val.is_a?(Array) ? emit(key, *val) : emit(key, val) if val != old_status[key]
            end
          end
          
          old_status = status
          sleep 0.1

          if !connected
            sleep 2
            begin
              mpd.connect unless @stop_cb_thread
            rescue
            end
          end
        end
      }
    end

    return true
  end

  # Check if the client is connected
  #
  # @return [Boolean] True only if the server responds otherwise false
  def connected?
    return false if !@socket

    ret = send_command(:ping) rescue false
    return ret
  end


  # Waits until there is a noteworthy change in one or more of MPD's subsystems. 
  # As soon as there is one, it lists all changed systems in a line in the format 
  # 'changed: SUBSYSTEM', where SUBSYSTEM is one of the following:
  #
  # * *database*: the song database has been modified after update.
  # * *update*: a database update has started or finished. If the database was modified 
  #   during the update, the database event is also emitted.
  # * *stored_playlist*: a stored playlist has been modified, renamed, created or deleted
  # * *playlist*: the current playlist has been modified
  # * *player*: the player has been started, stopped or seeked
  # * *mixer*: the volume has been changed
  # * *output*: an audio output has been enabled or disabled
  # * *options*: options like repeat, random, crossfade, replay gain
  # * *sticker*: the sticker database has been modified.
  # * *subscription*: a client has subscribed or unsubscribed to a channel
  # * *message*: a message was received on a channel this client is subscribed to; this 
  #   event is only emitted when the queue is empty
  #
  # If the optional +masks+ argument is used, MPD will only send notifications 
  # when something changed in one of the specified subsytems.
  #
  # @since MPD 0.14
  # @param [Symbol] masks A list of subsystems we want to be notified on.
  def idle(*masks)
    send_command(:idle, *masks)
  end 

  # Disconnect from the server. This has no effect
  # if the client is not connected. Reconnect using
  # the connect method. This will also stop the
  # callback thread, thus disabling callbacks
  def disconnect
    @stop_cb_thread = true

    return if @socket.nil?

    @socket.puts 'close'
    @socket.close
    @socket = nil
  end

  # Returns the config of MPD (currently only music_directory).
  # Only works if connected trough an UNIX domain socket.
  # @return [Hash] Configuration of MPD
  def config
    send_command :config
  end

  # Add the file _path_ to the playlist. If path is a
  # directory, it will be added recursively.
  # @macro returnraise
  def add(path)
    send_command :add, path
  end

  # Clears the current playlist
  # @macro returnraise
  def clear
    send_command :clear
  end

  # Clears the current error message reported in status
  # (also accomplished by any command that starts playback)
  #
  # @macro returnraise
  def clearerror
    send_command :clearerror
  end

  # Set the crossfade between songs in seconds.
  # @macro returnraise
  def crossfade=(seconds)
    send_command :crossfade, seconds
  end

  # @return [Integer] Crossfade in seconds.
  def crossfade
    return status[:xfade]
  end

  # Get the currently playing song
  #
  # @return [MPD::Song]
  def current_song
    Song.new send_command :currentsong
  end

  # Delete the song from the playlist, where pos is the song's
  # position in the playlist
  # @macro returnraise
  def delete(pos)
    send_command :delete, pos
  end

  # Delete the song with the +songid+ from the playlist.
  # @macro returnraise
  def deleteid(songid)
    send_command :deleteid, songid
  end

  # Finds songs in the database that are EXACTLY
  # matched by the what argument. type should be
  # 'album', 'artist', or 'title'
  # 
  # @return [Array<MPD::Song>] Songs that matched.
  def find(type, what)
    build_songs_list send_command(:find, type, what)
  end

  # Kills the MPD process.
  # @macro returnraise
  def kill
    send_command :kill
  end

  # Lists all of the albums in the database
  # The optional argument is for specifying an
  # artist to list the albums for
  #
  # @return [Array<String>] An array of album names.
  def albums(artist = nil)
    list :album, artist
  end

  # Lists all of the artists in the database
  #
  # @return [Array<String>] An array of artist names.
  def artists
    list :artist
  end

  # This is used by the albums and artists methods
  # type should be 'album' or 'artist'. If type is 'album'
  # then arg can be a specific artist to list the albums for
  #
  # @return [Array<String>]
  def list(type, arg = nil)
    response = send_command :list, type, arg

    list = []
    if not response.nil? and response.kind_of? String
      lines = response.split "\n"
      re = Regexp.new "\\A#{type}: ", 'i'
      for line in lines
        list << line.gsub(re, '')
      end
    end

    return list
  end

  # List all of the directories in the database, starting at path.
  # If path isn't specified, the root of the database is used
  #
  # @return [Array<String>] Array of directory names
  def directories(path = nil)
    response = send_command :listall, path
    filter_response response, :directory
  end

  # List all of the files in the database, starting at path.
  # If path isn't specified, the root of the database is used
  #
  # @return [Array<String>] Array of file names
  def files(path = nil)
    response = send_command :listall, path
    filter_response response, :file
  end

  # List all of the playlists in the database
  # 
  # @return [Array<String>] Array of playlist names
  def playlists
    response = send_command :lsinfo
    filter_response response, :playlist
  end

  # List all of the songs in the database starting at path.
  # If path isn't specified, the root of the database is used
  #
  # @return [Array<MPD::Song>]
  def songs(path = nil)
    build_songs_list send_command(:listallinfo, path)
  end

  # List all of the songs by an artist
  #
  # @return [Array<MPD::Song>]
  def songs_by_artist(artist)
    all_songs = self.songs
    artist_songs = []
    all_songs.each do |song|
      if song.artist == artist
        artist_songs << song
      end
    end

    return artist_songs
  end

  # Loads the playlist name.m3u (do not pass the m3u extension
  # when calling) from the playlist directory. Use `playlists`
  # to what playlists are available
  # 
  # @macro returnraise
  def load(name)
    send_command :load, name
  end

  # Move the song at `from` to `to` in the playlist.
  # @macro returnraise
  def move(from, to)
    send_command :move, from, to
  end

  # Move the song with the `songid` to `to` in the playlist.
  # @macro returnraise
  def moveid(songid, to)
    send_command :moveid, songid, to
  end

  # Plays the next song in the playlist.
  # @macro returnraise
  def next
    send_command :next
  end

  # Resume/pause playback.
  # @macro returnraise
  def pause=(toggle)
    send_command :pause, toggle
  end

  # Is MPD paused?
  # @return [Boolean]
  def paused?
    return status[:state] == :pause
  end

  # Used for authentication with the server
  # @param [String] pass Plaintext password
  def password(pass)
    send_command :password, pass
  end

  # Ping the server.
  # @macro returnraise
  def ping
    send_command :ping
  end

  # Begin playing the playist.   
  # @param [Integer] pos Position in the playlist to start playing.
  # @macro returnraise
  def play(pos = nil)
    send_command :play, pos
  end

  # Is MPD playing?
  # @return [Boolean]
  def playing?
    return status[:state] == :play
  end

  # Begin playing the playlist.
  # @param [Integer] songid ID of the song where to start playing.
  # @macro returnraise
  def playid(songid = nil)
    send_command :playid, songid
  end

  # @return [Integer] Current playlist version number.
  def playlist_version
    status[:playlist]
  end

  # List the current playlist.
  # This is the same as playlistinfo without args.
  #
  # @return [Array<MPD::Song>] Array of songs in the playlist.
  def playlist
    build_songs_list send_command(:playlistinfo)
  end

  # Returns the song at the position +pos+ in the playlist,
  # @return [MPD::Song]
  def song_at_pos(pos)
    Song.new send_command(:playlistinfo, pos)
  end

  # Returns the song with the +songid+ in the playlist,
  # @return [MPD::Song]
  def song_with_id(songid)
    Song.new send_command(:playlistid, songid)
  end

  # List the changes since the specified version in the playlist
  # @return [Array<MPD::Song>]
  def playlist_changes(version)
    build_songs_list send_command(:plchanges, version)
  end

  # Plays the previous song in the playlist
  # @macro returnraise
  def previous
    send_command :previous
  end

  # Enable/disable consume mode.
  # @since MPD 0.16
  # When consume is activated, each song played is removed from playlist 
  # after playing.
  # @macro returnraise
  def consume=(toggle)
    send_command :consume, toggle
  end

  # Returns true if consume is enabled.
  def consume?
    return status[:consume]
  end

  # Enable/disable single mode.
  # @since MPD 0.15
  # When single is activated, playback is stopped after current song,
  # or song is repeated if the 'repeat' mode is enabled.
  # @macro returnraise
  def single=(toggle)
    send_command :single, toggle
  end

  # Returns true if single is enabled.
  def single?
    return status[:single]
  end

  # Enable/disable random playback.
  # @macro returnraise
  def random=(toggle)
    send_command :random, toggle
  end

  # Returns true if random playback is currently enabled,
  def random?
    return status[:random]
  end

  # Enable/disable repeat mode.
  # @macro returnraise
  def repeat=(toggle)
    send_command :repeat, toggle
  end

  # Returns true if repeat is enabled,
  def repeat?
    return status[:repeat]
  end

  # Removes (*PERMANENTLY!*) the playlist +playlist.m3u+ from
  # the playlist directory
  # @macro returnraise
  def rm(playlist)
    send_command :rm, playlist
  end

  alias :remove_playlist :rm

  # Saves the current playlist to `playlist`.m3u in the
  # playlist directory
  # @macro returnraise
  def save(playlist)
    send_command :save, playlist
  end

  # Searches for any song that contains `what` in the `type` field
  # `type` can be 'title', 'artist', 'album' or 'filename'
  # `type`can also be 'any'
  # Searches are NOT case sensitive.
  #
  # @return [Array<MPD::Song>] Songs that matched.
  def search(type, what)
    build_songs_list(send_command(:search, type, what))
  end

  # Seeks to the position in seconds within the current song.
  # If prefixed by '+' or '-', then the time is relative to the current
  # playing position.
  #
  # @since MPD 0.17
  # @param [Integer, String] time Position within the current song.
  # Returns true if successful,
  def seek(time)
    send_command :seekcur, time
  end

  # Seeks to the position +time+ (in seconds) of the
  # song at +pos+ in the playlist.
  # @macro returnraise
  def seekpos(pos, time)
    send_command :seek, pos, time
  end

  # Seeks to the position `time` (in seconds) of the song with
  # the id `songid`.
  # @macro returnraise
  def seekid(songid, time)
    send_command :seekid, songid, time
  end

  # Sets the volume level.
  # @param [Integer] vol Volume level between 0 and 100.
  # @macro returnraise
  def volume=(vol)
    send_command :setvol, vol
  end

  # Gets the volume level.
  # @return [Integer]
  def volume
    return status[:volume]
  end

  # Shuffles the playlist.
  # @macro returnraise
  def shuffle
    send_command :shuffle
  end

  # @return [Hash] MPD statistics.
  def stats
    send_command :stats
  end

  # @return [Hash] Current MPD status.
  def status
    send_command :status
  end

  # Stop playing
  # @macro returnraise
  def stop
    send_command :stop
  end

  # @return [Boolean] Is MPD stopped?
  def stopped?
    return status[:state] == :stop
  end

  # Swaps the song at position `posA` with the song
  # as position `posB` in the playlist
  # @macro returnraise
  def swap(posA, posB)
    send_command :swap, posA, posB
  end

  # Swaps the song with the id `songidA` with the song
  # with the id `songidB`
  # @macro returnraise
  def swapid(songidA, songidB)
    send_command :swapid, songidA, songidB
  end

  # Tell the server to update the database. Optionally,
  # specify the path to update
  #
  # @return [Integer] Update job ID
  def update(path = nil)
    ret = send_command(:update, path)
    return ret #ret[:updating_db]
  end

  # Gives a list of all outputs
  # @return [Array<Hash>] An array of outputs.
  def outputs
    send_command :outputs
  end

  # Enables specified output.
  # @param [Integer] num Number of the output to enable.
  # @macro returnraise
  def enableoutput(num)
    send_command :enableoutput, num
  end

  # Disables specified output.
  # @param [Integer] num Number of the output to disable.
  # @macro returnraise
  def disableoutput(num)
    send_command :disableoutput, num
  end


  private # Private Methods below

  # Private Method
  #
  # Used to send a command to the server. This synchronizes
  # on a mutex to be thread safe
  #
  # Returns the server response as processed by `handle_server_response`,
  # Raises a RuntimeError if the command failed
  def send_command(command, *args)
    raise MPDError, "Not Connected to the Server" if @socket.nil?

    data = convert_command(command, *args)
    ret = nil

    @mutex.synchronize do
      begin
        @socket.puts data
        ret = handle_server_response
      rescue Errno::EPIPE
        @socket = nil
        raise MPDError, 'Broken Pipe (Disconnected)'
      end
    end

    return ret
  end

  # Private Method
  #
  # Parses the command into MPD format.
  def convert_command(command, *args)
    args.map! {|word| 
      if word.is_a?(TrueClass) || word.is_a?(FalseClass) 
        word ? '1' : '0' # convert bool to 1 or 0
      else
        word.to_s
      end
    }
    # escape any strings with space (wrap in double quotes)
    args.map! {|word| word.match(/\s/) ? %Q["#{word}"] : word }
    return [command, args].join(' ').strip
  end

  # Private Method
  #
  # Handles the server's response (called inside send_command)
  #
  # This will repeatedly read the server's response from the socket
  # and will process the output. If a string is returned by the server
  # that is what is returned. If just an "OK" is returned, this returns
  # true. If an "ACK" is returned, this raises an error
  def handle_server_response
    return if @socket.nil?

    msg = ''
    reading = true
    error = nil
    while reading
      line = @socket.gets
      case line
      when "OK\n", nil
        reading = false
      when /^ACK/
        error = line
        reading = false
      else
        msg += line
      end
    end

    if !error
      return true if msg.empty?
      return build_response(msg)
    else
      err = error.match(/^ACK \[(?<code>\d+)\@(?<pos>\d+)\] \{(?<command>.+)\} (?<message>.+)$/)
      raise MPDError, "#{err[:code]}: #{err[:command]}: #{err[:message]}"
    end
  end

  # Private Method
  #
  # Parses response line into an object.
  def parse_line(string)
    return nil if string.nil?
    key, value = string.split(': ', 2)
    key = key.downcase.to_sym
    return parse_key(key, value.chomp)
  end


  # Private Method
  #
  # This builds a hash out of lines returned from the server,
  # elements parsed into the correct type.
  #
  # The end result is a hash containing the proper key/value pairs
  def build_hash(string)
    return {} if string.nil?

    hash = {}
    string.split("\n").each do |line|
      key, value = line.split(': ', 2)
      key = key.downcase.to_sym
      hash[key] = parse_key(key, value.chomp)
    end

    return hash
  end

  INT_KEYS = [
    :song, :artists, :albums, :songs, :uptime, :playtime, :db_playtime, :volume,
    :playlistlength, :xfade, :pos, :id, :date, :track, :disc, :outputid, :mixrampdelay,
    :bitrate, :nextsong, :nextsongid, :songid, :playlist, :updating_db,
    # musicbrainz
    :musicbrainz_trackid, :musicbrainz_artistid, :musicbrainz_albumid, :musicbrainz_albumartistid
  ]
  SYM_KEYS = [:command, :state, :changed, :replay_gain_mode]
  FLOAT_KEYS = [:mixrampdb, :elapsed]
  BOOL_KEYS = [:repeat, :random, :single, :consume, :outputenabled]

  # Private Method
  #
  # parses key-value pairs into correct class
  require 'time'
  def parse_key key, value
    if INT_KEYS.include? key
      value.to_i
    elsif FLOAT_KEYS.include? key
      value == 'nan' ? Float::NAN : value.to_f
    elsif BOOL_KEYS.include? key
      value != '0'
    elsif SYM_KEYS.include? key
      value.to_sym
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

  # Private Method
  #
  # Make chunks from string.
  def make_chunks(string)
    first_key = string.match(/\A(.+?): /)[1]

    chunks = string.split(/\n(?=#{first_key})/)
    list = chunks.inject([]) do |result, chunk|
      result << chunk.strip
    end
  end

  # Private Method
  #
  # Uses the chunks to create MPD::Song objects.
  # @return [Array<MPD::Song>] An array of songs.
  def build_songs_list(array)
    return array.map {|hash| Song.new(hash) }
  end

  # Private Method
  #
  # Generates chunks from a lines string and then parses
  # the chunks into an array of hashes.
  #
  # The end result is an Array of Hashes(containing the outputs)
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

  # Private Method
  #
  # This filters each line from the server to return
  # only those matching the regexp. The regexp is removed
  # from the line before it is added to an Array
  #
  # This is used in the `directories`, `files`, etc methods
  # to return only the directory/file names
  def filter_response(string, filter)
    regexp = Regexp.new("\A#{filter}: ", Regexp::IGNORECASE)
    list = []
    string.split("\n").each do |line|
      if line =~ regexp
        list << line.gsub(regexp, '')
      end
    end

    return list
  end

end
