require_relative 'song'

# TODO: add support for config (music_directory) - UNIX domain socket!

# TODO:
# 0.14
# * commands:
#  - "addid" takes optional second argument to specify position
#  - "idle" notifies the client when a notable change occurs
# 0.15
# * commands:
#  - "playlistinfo" and "move" supports a range now
#  - added "sticker database", command "sticker", which allows clients
#     to implement features like "song rating"
#  - added "consume" command which removes a song after play
#  - added "single" command, if activated, stops playback after current song or
#     repeats the song if "repeat" is active.
# * protocol:
# - send song modification time to client
#  - added "update" idle event
#  - removed the deprecated "volume" command
#  - added the "findadd" command
#  - range support for "delete"
#  - "previous" really plays the previous song
#  - "addid" with negative position is deprecated
#  - "load" supports remote playlists (extm3u, pls, asx, xspf, lastfm://)
#  - allow changing replay gain mode on-the-fly
#  - omitting the range end is possible
#  - "update" checks if the path is malformed
# * commands:
#  - added new "status" line with more precise "elapsed time"
# ver 0.17 (2012/06/27)
# * protocol:
#  - support client-to-client communication
#  - "update" and "rescan" need only "CONTROL" permission
#  - new command "seekcur" for simpler seeking within current song
#  - new command "config" dumps location of music directory
#  - add range parameter to command "load"
#  - print extra "playlist" object for embedded CUE sheets
#  - new commands "searchadd", "searchaddpl"


class MPD

  require 'socket'
  require 'thread'

  MPD_IDLE_MASK_DATABASE = 0x1 # song database has been updated
  MPD_IDLE_MASK_STORED_PLAYLIST = 0x2 # a stored playlist has been modified, created, deleted or renamed
  MPD_IDLE_MASK_QUEUE = 0x4 # the queue has been modified 
  MPD_IDLE_MASK_PLAYER = 0x8 # the player state has changed: play, stop, pause, seek, ...
  MPD_IDLE_MASK_MIXER = 0x10 # the volume has been modified
  MPD_IDLE_MASK_OUTPUT = 0x20 # an audio output device has been enabled or disabled 
  MPD_IDLE_MASK_OPTIONS = 0x40 # options have changed: crossfade, random, repeat, ...
  MPD_IDLE_MASK_UPDATE = 0x80 # a database update has started or finished.
  MPD_IDLE_MASK_ALL = MPD_IDLE_MASK_DATABASE | MPD_IDLE_MASK_STORED_PLAYLIST |
    MPD_IDLE_MASK_QUEUE | MPD_IDLE_MASK_PLAYER | MPD_IDLE_MASK_MIXER | MPD_IDLE_MASK_OUTPUT |
    MPD_IDLE_MASK_OPTIONS | MPD_IDLE_MASK_UPDATE

  IDLE_NAMES = {
    MPD_IDLE_MASK_DATABASE => "database", 
    MPD_IDLE_MASK_STORED_PLAYLIST => "stored_playlist", 
    MPD_IDLE_MASK_QUEUE => "playlist",
    MPD_IDLE_MASK_PLAYER => "player",
    MPD_IDLE_MASK_MIXER => "mixer",
    MPD_IDLE_MASK_OUTPUT => "output",
    MPD_IDLE_MASK_OPTIONS => "options",
    MPD_IDLE_MASK_UPDATE => "update"
  }

  # Initialize an MPD object with the specified hostname and port
  # When called without arguments, 'localhost' and 6600 are used
  def initialize(hostname = 'localhost', port = 6600)
    @hostname = hostname
    @port = port
    @socket = nil
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

  # Trigger a callback
  def emit(event, *args)
    p "#{event} was triggered!"
    @callbacks[event] ||= []
    @callbacks[event].each do |cb|
      cb.call *args
    end
  end

  # Connect to the daemon
  # When called without any arguments, this will just
  # connect to the server and wait for your commands
  # When called with true as an argument, this will
  # enable callbacks by starting a seperate polling thread.
  # This polling thread will also automatically reconnect
  # If is disconnected for whatever reason.
  #
  # connect will return OK plus the version string
  # if successful, otherwise an error will be raised
  #
  # If connect is called on an already connected instance,
  # a RuntimeError is raised
  def connect(callbacks = false)
    if self.connected?
      raise 'MPD Error: Already Connected'
    end

    @socket = File.exists?(@hostname) ? UNIXSocket.new(@hostname) : TCPSocket.new(@hostname, @port)
    ret = @socket.gets.chomp # Read the version

    if callbacks and (@cb_thread.nil? or !@cb_thread.alive?)
      @stop_cb_thread = false
      @cb_thread = Thread.new(self) { |mpd|
        old_status = {}
        song = ''
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

    return ret
  end

  # Check if the client is connected
  #
  # This will return true only if the server responds
  # otherwise false is returned
  def connected?
    return false if !@socket

    ret = send_command(:ping) rescue false
    return ret
  end

  def idle(mask = MPD_IDLE_MASK_ALL)
    begin
      if mask == MPD_IDLE_MASK_ALL
        ret = send_command :idle
      else
        idle_masks = []
        IDLE_NAMES.keys.each do |idle_mask_key|
          if (mask & idle_mask_key) == idle_mask_key
            idle_masks << IDLE_NAMES[idle_mask_key]
          end
        end
        idle_name = idle_masks.join(",")
        ret = send_command(:idle, idle_name)
      end
    rescue
      ret = nil
    end

    return ret
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

  # Add the file _path_ to the playlist. If path is a
  # directory, it will be added recursively.
  #
  # Returns true if this was successful,
  def add(path)
    send_command :add, path
  end

  # Clears the current playlist
  #
  # Returns true if this was successful,
  def clear
    send_command :clear
  end

  # Clears the current error message reported in status
  # (This is also accomplished by any command that starts playback)
  #
  # Returns true if this was successful,
  def clearerror
    send_command :clearerror
  end

  # Set the crossfade between songs in seconds
  def crossfade=(seconds)
    send_command :crossfade, seconds
  end

  # Read the crossfade between songs in seconds,
  def crossfade
    return status[:xfade]
  end

  # Read the currently playing song
  #
  # Returns a Song object with the current song's data,
  def current_song
    build_song(send_command :currentsong)
  end

  # Delete the song from the playlist, where pos
  # is the song's position in the playlist
  #
  # Returns true if successful,
  def delete(pos)
    send_command :delete, pos
  end

  # Delete the song with the songid from the playlist
  #
  # Returns true if successful,
  def deleteid(songid)
    send_command :deleteid, songid
  end

  # Finds songs in the database that are EXACTLY
  # matched by the what argument. type should be
  # 'album', 'artist', or 'title'
  # 
  # This returns an Array of MPD::Songs,
  def find(type, what)
    response = send_command(:find, type, what)
    build_songs_list response
  end

  # Kills MPD
  #
  # Returns true if successful.
  def kill
    send_command :kill
  end

  # Lists all of the albums in the database
  # The optional argument is for specifying an
  # artist to list the albums for
  #
  # Returns an Array of Album names (Strings),
  def albums(artist = nil)
    list :album, artist
  end

  # Lists all of the artists in the database
  #
  # Returns an Array of Artist names (Strings),
  def artists
    list :artist
  end

  # This is used by the albums and artists methods
  # type should be 'album' or 'artist'. If type is 'album'
  # then arg can be a specific artist to list the albums for
  #
  # Returns an Array of Strings,
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
  # Returns an Array of directory names (Strings),
  def directories(path = nil)
    response = send_command :listall, path
    filter_response response, :directory
  end

  # List all of the files in the database, starting at path.
  # If path isn't specified, the root of the database is used
  #
  # Returns an Array of file names (Strings).
  def files(path = nil)
    response = send_command :listall, path
    filter_response response, :file
  end

  # List all of the playlists in the database
  # 
  # Returns an Array of playlist names (Strings)
  def playlists
    response = send_command :lsinfo
    filter_response response, :playlist
  end

  # List all of the songs in the database starting at path.
  # If path isn't specified, the root of the database is used
  #
  # Returns an Array of MPD::Songs,
  def songs(path = nil)
    response = send_command :listallinfo, path
    build_songs_list response
  end

  # List all of the songs by an artist
  #
  # Returns an Array of MPD::Songs by the artist `artist`,
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
  # Returns true if successful,
  def load(name)
    send_command :load, name
  end

  # Move the song at `from` to `to` in the playlist
  #
  # Returns true if successful,
  def move(from, to)
    send_command :move, from, to
  end

  # Move the song with the `songid` to `to` in the playlist
  #
  # Returns true if successful,
  def moveid(songid, to)
    send_command :moveid, songid, to
  end

  # Plays the next song in the playlist
  #
  # Returns true if successful,
  def next
    send_command :next
  end

  # Set / Unset paused playback
  #
  # Returns true if successful,
  def pause=(toggle)
    send_command :pause, toggle
  end

  # Returns true if MPD is paused,
  def paused?
    return status[:state] == :pause
  end

  # This is used for authentication with the server
  # `pass` is simply the plaintext password
  def password(pass)
    send_command :password, pass
  end

  # Ping the server
  #
  # Returns true if successful,
  def ping
    send_command :ping
  end

  # Begin playing the playist. Optionally
  # specify the pos to start on
  #
  # Returns true if successful,
  def play(pos = nil)
    send_command :play, pos
  end

  # Returns true if MPD is playing.
  def playing?
    return status[:state] == :play
  end

  # Begin playing the playlist. Optionally
  # specify the songid to start on
  #
  # Returns true if successful,
  def playid(songid = nil)
    send_command :playid, songid
  end

  # Returns the current playlist version number,
  def playlist_version
    status[:playlist]
  end

  # List the current playlist
  # This is the same as playlistinfo w/o args
  #
  # Returns an Array of MPD::Songs,
  def playlist
    response = send_command :playlistinfo
    build_songs_list response
  end

  # Returns the MPD::Song at the position `pos` in the playlist,
  def song_at_pos(pos)
    build_song(send_command(:playlistinfo, pos))
  end

  # Returns the MPD::Song with the `songid` in the playlist,
  def song_with_id(songid)
    build_song(send_command(:playlistid songid))
  end

  # List the changes since the specified version in the playlist
  #
  # Returns an Array of MPD::Songs,
  def playlist_changes(version)
    response = send_command :plchanges, version
    build_songs_list response
  end

  # Plays the previous song in the playlist
  #
  # Returns true if successful,
  def previous
    send_command :previous
  end

  # Enable/Disable consume (MPD 0.16)
  # When consume is activated, each song played is removed 
  # from playlist after playing.
  def consume=(toggle)
    send_command :consume, toggle
  end

  # Returns true if consume is enabled.
  def consume?
    return status[:consume]
  end

  # Enable / Disable random playback,
  def random=(toggle)
    send_command :random, toggle
  end

  # Returns true if random playback is currently enabled,
  def random?
    return status[:random]
  end

  # Enable / Disable repeat,
  def repeat=(toggle)
    send_command :repeat, toggle
  end

  # Returns true if repeat is enabled,
  def repeat?
    return status[:repeat]
  end

  # Removes (PERMANENTLY!) the playlist `playlist.m3u` from
  # the playlist directory
  #
  # Returns true if successful,
  def rm(playlist)
    send_command :rm, playlist
  end

  # An Alias for rm
  def remove_playlist(playlist)
    rm playlist
  end

  # Saves the current playlist to `playlist`.m3u in the
  # playlist directory
  #
  # Returns true if successful,
  def save(playlist)
    send_command :save, playlist
  end

  # Searches for any song that contains `what` in the `type` field
  # `type` can be 'title', 'artist', 'album' or 'filename'
  # Searches are NOT case sensitive
  #
  # Returns an Array of MPD::Songs,
  def search(type, what)
    build_songs_list(send_command(:search, type, what))
  end

  # Seeks to the position `time` (in seconds) of the
  # song at `pos` in the playlist
  #
  # Returns true if successful,
  def seek(pos, time)
    send_command :seek, pos time
  end

  # Seeks to the position `time` (in seconds) of the song with
  # the id `songid`
  #
  # Returns true if successful,
  def seekid(songid, time)
    send_command :seekid, songid, time
  end

  # Set the volume
  # The argument `vol` will automatically be bounded to 0 - 100
  def volume=(vol)
    send_command :setvol, vol
  end

  # Returns the volume,
  def volume
    return status[:volume]
  end

  # Shuffles the playlist,
  def shuffle
    send_command :shuffle
  end

  # Returns a Hash of MPD's stats,
  def stats
    response = send_command :stats
    build_hash response
  end

  # Returns a Hash of the current status,
  def status
    response = send_command :status
    return build_hash response
  end

  # Stop playing
  #
  # Returns true if successful,
  def stop
    send_command :stop
  end

  # Returns true if the server's state is 'stop',
  def stopped?
    return status[:state] == :stop
  end

  # Swaps the song at position `posA` with the song
  # as position `posB` in the playlist
  #
  # Returns true if successful,
  # Raises a RuntimeError if the command failed
  def swap(posA, posB)
    send_command :swap, posA, posB
  end

  # Swaps the song with the id `songidA` with the song
  # with the id `songidB`
  #
  # Returns true if successful,
  # Raises a RuntimeError if the command failed
  def swapid(songidA, songidB)
    send_command :swapid, songidA}, songidB
  end

  # Tell the server to update the database. Optionally,
  # specify the path to update
  #
  # Returns the update job id.
  def update(path = nil)
    ret = build_hash(send_command(:update, path))
    return ret[:updating_db]
  end

  # Gives a list of all outputs
  def outputs
    build_list(send_command :outputs)
  end

  # Enables output num
  def enableoutput(num)
    send_command :enableoutput, num
  end

  # Disables output num
  def disableoutput(num)
    send_command :disableoutput, num
  end


  # Private Method
  #
  # Used to send a command to the server. This synchronizes
  # on a mutex to be thread safe
  #
  # Returns the server response as processed by `handle_server_response`,
  # Raises a RuntimeError if the command failed
  def send_command(command, *args)
    raise "MPD: Not Connected to the Server" if @socket.nil?

    args.map! {|word| 
      if word.is_a?(TrueClass) || word.is_a?(FalseClass) 
        word ? '1' : '0' # convert bool to 1 or 0
      else
        word.to_s
      end
    }
    # escape any strings with space (wrap in double quotes)
    args.map! {|word| word.match(/\s/) ? %Q["#{word}"] : word }
    data = [command, args].join(' ').strip

    ret = nil

    @mutex.synchronize do
      begin
        @socket.puts data
        ret = handle_server_response
      rescue Errno::EPIPE
        @socket = nil
        raise 'MPD Error: Broken Pipe (Disconnected)'
      end
    end

    return ret
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
      return msg
    else
      raise error.gsub( /^ACK \[(\d+)\@(\d+)\] \{(.+)\} (.+)$/, 'MPD Error #\1: \3: \4') 
    end
  end

  # Private Method
  #
  # This builds a hash out of lines returned from the server.
  # It detects the key types and converts them into the correct
  # class.
  #
  # The end result is a hash containing the proper key/value pairs
  def build_hash(string)
    return {} if string.nil?

    hash = {}
    string.split("\n").each do |line|
      key, value = line.split(': ', 2)
      key = key.downcase.to_sym
      value = parse_key(key, value.chomp)

      hash[key] = value
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

  # parses keys into correct class
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
    elsif key == :time
      value.split(':').map(&:to_i)
    elsif key == :audio
      value.split(':').map(&:to_i)
    else
      value.force_encoding('UTF-8')
    end
  end

  # Make chunks from string.
  def make_chunks(string)
    first_key = string.match(/\A(.+?): /)[1]

    chunks = string.split(/\n(?=#{first_key})/)
    list = chunks.inject([]) do |result, chunk|
      result << chunk
    end
  end

  # Private Method
  #
  # This is similar to build_hash, but instead of building a Hash,
  # a MPD::Song is built.
  def build_song(string)
    return nil if string.nil? || !string.is_a?(String)

    options = build_hash(string)
    return Song.new(options)
  end

  # Private Method
  #
  # Uses the chunks to create MPD::Song objects.
  #
  # The end result is an Array of MPD::Songs
  def build_songs_list(string)
    return [] if string.nil? || !string.is_a?(String)

    chunks = make_chunks(string)
    list = chunks.inject([]) do |result, chunk|
      result << build_song(chunk)
    end

    return list.compact
  end

  # Private Method
  #
  # Generates chunks from a lines string and then parses
  # the chunks into an array of hashes.
  #
  # The end result is an Array of Hashes(containing the outputs)
  def build_list(string)
    return [] if string.nil? || !string.is_a?(String)

    chunks = make_chunks(string)
    list = chunks.inject([]) do |result, chunk|
      result << build_hash(chunk)
    end

    return list
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

  private :send_command
  private :handle_server_response
  private :build_hash
  private :parse_key
  private :build_song
  private :build_songs_list
  private :build_list
  private :filter_response

end
