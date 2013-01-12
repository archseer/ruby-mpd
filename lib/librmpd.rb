#
#== librmpd.rb
#
# librmpd.rb is another Ruby MPD Library with a goal of greater
# ease of use, more functionality, and thread safety
#
# Author:: Andrew Rader (bitwise_mcgee AT yahoo.com | http://nymb.us)
# Copyright:: Copyright (c) 2006 Andrew Rader
# License:: Distributed under the GNU GPL v2 (See COPYING file)
#
# This was written with MPD version 0.11.5 (http://www.musicpd.org)
#
# The main class is the MPD class. This provides the functionality for
# talking to the server as well as setting up callbacks for when events
# occur (such as song changes, state changes, etc). The use of callbacks
# is optional, if they are used a seperate thread will continuously poll
# the server on its status, when something is changed, your program will
# be notified via any callbacks you have set. Most methods are the same
# as specified in the MPD Server Protocol, however some have been modified
# or renamed. Most notable is the list* and lsinfo functions have been
# replace with more sane methods (such as `files` for all files)
#
#== Usage
#
# First create an MPD object
#
#  require 'rubygems'
#  require 'librmpd'
#
#  mpd = MPD.new 'localhost', 6600
#
# and connect it to the server
#
#  mpd.connect
#
# You can now issue any of the commands. Each command is documented below.
#
#=== Callbacks
#
# Callbacks are a way to easily setup your client as event based, rather
# than polling based. This means rather than having to check for changes
# in the server, you setup a few methods that will be called when those
# changes occur. For example, you could have a 'state_changed' method
# that will be called whenever the server changes state. You could then
# have this method change a label to reflect to the new state.
#
# To use callbacks in your program, first setup your callback methods. For
# example, say you have the class MyClient. Simply define whatever
# callbacks you want inside your class. See the documentation on the
# callback type constants in the MPD class for details on how each callback
# is called
#
# Once you have your callback methods defined, use the register_callback
# methods to inform librmpd about them. You can have multiple callbacks
# for each type of callback without problems. Simply use object.method('method_name')
# to get a reference to a Method object. Pass this object to the
# register_callback (along with the proper type value), and you're set.
#       
# An Example:
#
#   class MyClient
#    ...
#    def state_callback(newstate)
#     puts "MPD Changed State: #{newstate}"
#    end
#    ...
#   end
#
#   client = MyClient.new
#   mpd = MPD.new
#   mpd.register_callback(client.method('state_callback'), MPD::STATE_CALLBACK)
#       
#   # Connect and Enable Callbacks
#   mpd.connect(true)
#
# In order for the callback to be used, you must enable callbacks when you
# connect by passing true to the connect method. Now, whenever the state changes
# on the server, myclientobj's state_callback method will be called (and passed
# the new state as an argument)

class MPD

  require 'socket'
  require 'thread'

  STATUS_KEYS = [
    :volume, :repeat, :random, :single, :consume, 
    :playlist, :playlistlength, :state, 
    :song, :songid, :nextsong, :nextsongid, 
    :time, :elapsed, :bitrate, :xfade, 
    :audio
  ]
  STRING_KEYS = [:state]
  BOOL_KEYS = [:repeat, :random, :single, :consume]
  IGNORE_KEYS = [:song, :time, :audio]

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

  #
  #== Song
  #
  # This class is a glorified Hash used to represent a song.
  #
  # If the field doesn't exist or isn't set, nil will be returned
  #
  class Song
    def initialize(options)
      @data = {}

      @length = options.delete(:time).to_i
      @data.merge! options
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

  # This will store the given method onto the given type's callback
  # list. First you must get a reference to the method to call by
  # the following:
  #
  #   callback_method = my_object.method 'method name'
  #
  # Then you can call register_callback:
  #
  #   mpd.register_callback(event, callback_method)
  #
  # Now my_object's 'method name' method will be called whenever the
  # state changes
  def register_callback(event, method)
    @callbacks[event] ||= []
    @callbacks[event].push method
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

    @socket = TCPSocket::new @hostname, @port
    ret = @socket.gets # Read the version

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

          MPD::STATUS_KEYS.each do |key|
            next if MPD::IGNORE_KEYS.include?(key)
            emit(key, status[key]) if status[key] != old_status[key]
          end

          if old_status[:time] != status[:time]
            if status[:time].nil? || status[:time].empty?
              emit(:time, 0, 0)
            else
              args = status[:time].split(':').map(&:to_i)
              #elapsed, total = args

              emit(:time, *args)
              # time emits elapsed, total
            end
          end

          emit(:song, mpd.current_song) if status[:song] != old_status[:song]

          if status[:audio] != old_status[:audio]
            if status[:audio].nil? || status[:audio].empty?
              emit(:audio, 0, 0, 0)
            else
              args = status[:audio].split(':').map(&:to_i)

              emit(:audio, *args)
              # audio emits samp, bits, chans
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
    return false if @socket.nil?

    ret = send_command('ping') rescue false
    return ret
  end

  def idle(mask = MPD_IDLE_MASK_ALL)
    begin
      if mask == MPD_IDLE_MASK_ALL
        ret = send_command 'idle'
      else
        idle_masks = []
        IDLE_NAMES.keys.each do |idle_mask_key|
          if (mask & idle_mask_key) == idle_mask_key
            idle_masks << IDLE_NAMES[idle_mask_key]
          end
        end
        idle_name = idle_masks.join(",")
        ret = send_command "idle #{idle_name}"
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
  # Raises a RuntimeError if the command failed
  def add(path)
    send_command "add \"#{path}\""
  end

  # Clears the current playlist
  #
  # Returns true if this was successful,
  # Raises a RuntimeError if the command failed
  def clear
    send_command :clear
  end

  # Clears the current error message reported in status
  # (This is also accomplished by any command that starts playback)
  #
  # Returns true if this was successful,
  # Raises a RuntimeError if the command failed
  def clearerror
    send_command :clearerror
  end

  # Set the crossfade between songs in seconds
  #
  # Raises a RuntimeError if the command failed
  def crossfade=(seconds)
    send_command "crossfade #{seconds}"
  end

  # Read the crossfade between songs in seconds,
  # Raises a RuntimeError if the command failed
  def crossfade
    status = self.status
    return status[:xfade]
  end

  # Read the currently playing song
  #
  # Returns a Song object with the current song's data,
  # Raises a RuntimeError if the command failed
  def current_song
    build_song(send_command(:currentsong))
  end

  # Delete the song from the playlist, where pos
  # is the song's position in the playlist
  #
  # Returns true if successful,
  # Raises a RuntimeError if the command failed
  def delete(pos)
    send_command "delete #{pos}"
  end

  # Delete the song with the songid from the playlist
  #
  # Returns true if successful,
  # Raises a RuntimeError if the command failed
  def deleteid(songid)
    send_command "deleteid #{songid}"
  end

  # Finds songs in the database that are EXACTLY
  # matched by the what argument. type should be
  # 'album', 'artist', or 'title'
  # 
  # This returns an Array of MPD::Songs,
  # Raises a RuntimeError if the command failed
  def find(type, what)
    response = send_command "find \"#{type}\" \"#{what}\""
    build_songs_list response
  end

  # Kills MPD
  #
  # Returns true if successful.
  # Raises a RuntimeError if the command failed
  def kill
    send_command :kill
  end

  # Lists all of the albums in the database
  # The optional argument is for specifying an
  # artist to list the albums for
  #
  # Returns an Array of Album names (Strings),
  # Raises a RuntimeError if the command failed
  def albums(artist = nil)
    list :album, artist
  end

  # Lists all of the artists in the database
  #
  # Returns an Array of Artist names (Strings),
  # Raises a RuntimeError if the command failed
  def artists
    list :artist
  end

  # This is used by the albums and artists methods
  # type should be 'album' or 'artist'. If type is 'album'
  # then arg can be a specific artist to list the albums for
  #
  # Returns an Array of Strings,
  # Raises a RuntimeError if the command failed
  def list(type, arg = nil)
    if not arg.nil?
      response = send_command "list #{type} \"#{arg}\""
    else
      response = send_command "list #{type}"
    end

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
  # Raises a RuntimeError if the command failed
  def directories(path = nil)
    if not path.nil?
      response = send_command "listall \"#{path}\""
    else
      response = send_command :listall
    end

    filter_response response, /\Adirectory: /i
  end

  # List all of the files in the database, starting at path.
  # If path isn't specified, the root of the database is used
  #
  # Returns an Array of file names (Strings).
  # Raises a RuntimeError if the command failed
  def files(path = nil)
    if not path.nil?
      response = send_command "listall \"#{path}\""
    else
      response = send_command :listall
    end

    filter_response response, /\Afile: /i
  end

  # List all of the playlists in the database
  # 
  # Returns an Array of playlist names (Strings)
  def playlists
    response = send_command :lsinfo

    filter_response response, /\Aplaylist: /i
  end

  # List all of the songs in the database starting at path.
  # If path isn't specified, the root of the database is used
  #
  # Returns an Array of MPD::Songs,
  # Raises a RuntimeError if the command failed
  def songs(path = nil)
    if not path.nil?
      response = send_command "listallinfo \"#{path}\""
    else
      response = send_command :listallinfo
    end

    build_songs_list response
  end

  # List all of the songs by an artist
  #
  # Returns an Array of MPD::Songs by the artist `artist`,
  # Raises a RuntimeError if the command failed
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
  # Raises a RuntimeError if the command failed
  def load(name)
    send_command "load \"#{name}\""
  end

  # Move the song at `from` to `to` in the playlist
  #
  # Returns true if successful,
  # Raises a RuntimeError if the command failed
  def move(from, to)
    send_command "move #{from} #{to}"
  end

  # Move the song with the `songid` to `to` in the playlist
  #
  # Returns true if successful,
  # Raises a RuntimeError if the command failed
  def moveid(songid, to)
    send_command "moveid #{songid} #{to}"
  end

  # Plays the next song in the playlist
  #
  # Returns true if successful,
  # Raises a RuntimeError if the command failed
  def next
    send_command :next
  end

  # Set / Unset paused playback
  #
  # Returns true if successful,
  # Raises a RuntimeError if the command failed
  def pause=(toggle)
    send_command 'pause ' + (toggle ? '1' : '0')
  end

  # Returns true if MPD is paused,
  # Raises a RuntimeError if the command failed
  def paused?
    status = self.status
    return status[:state] == 'pause'
  end

  # This is used for authentication with the server
  # `pass` is simply the plaintext password
  #
  # Raises a RuntimeError if the command failed
  def password(pass)
    send_command "password \"#{pass}\""
  end

  # Ping the server
  #
  # Returns true if successful,
  # Raises a RuntimeError if the command failed
  def ping
    send_command :ping
  end

  # Begin playing the playist. Optionally
  # specify the pos to start on
  #
  # Returns true if successful,
  # Raises a RuntimeError if the command failed
  def play(pos = nil)
    if pos.nil?
      return send_command(:play)
    else
      return send_command("play #{pos}")
    end
  end

  # Returns true if the server's state is set to 'play',
  # Raises a RuntimeError if the command failed
  def playing?
    state = self.status[:state]
    return state == 'play'
  end

  # Begin playing the playlist. Optionally
  # specify the songid to start on
  #
  # Returns true if successful,
  # Raises a RuntimeError if the command failed
  def playid(songid = nil)
    if not songid.nil?
      return (send_command("playid #{songid}"))
    else
      return (send_command :playid)
    end
  end

  # Returns the current playlist version number,
  # Raises a RuntimeError if the command failed
  def playlist_version
    self.status[:playlist]
  end

  # List the current playlist
  # This is the same as playlistinfo w/o args
  #
  # Returns an Array of MPD::Songs,
  # Raises a RuntimeError if the command failed
  def playlist
    response = send_command :playlistinfo
    build_songs_list response
  end

  # Returns the MPD::Song at the position `pos` in the playlist,
  # Raises a RuntimeError if the command failed
  def song_at_pos(pos)
    build_song(send_command("playlistinfo #{pos}"))
  end

  # Returns the MPD::Song with the `songid` in the playlist,
  # Raises a RuntimeError if the command failed
  def song_with_id(songid)
    build_song(send_command("playlistid #{songid}"))
  end

  # List the changes since the specified version in the playlist
  #
  # Returns an Array of MPD::Songs,
  # Raises a RuntimeError if the command failed
  def playlist_changes(version)
    response = send_command "plchanges #{version}"
    build_songs_list response
  end

  # Plays the previous song in the playlist
  #
  # Returns true if successful,
  # Raises a RuntimeError if the command failed
  def previous
    send_command :previous
  end

  # Enable / Disable random playback,
  # Raises a RuntimeError if the command failed
  def random=(toggle)
    send_command 'random ' + (toggle ? '1' : '0')
  end

  # Returns true if random playback is currently enabled,
  # Raises a RuntimeError if the command failed
  def random?
    return self.status[:random]
  end

  # Enable / Disable repeat,
  # Raises a RuntimeError if the command failed
  def repeat=(toggle)
    send_command 'repeat ' + (toggle ? '1' : '0')
  end

  # Returns true if repeat is enabled,
  # Raises a RuntimeError if the command failed
  def repeat?
    return self.status[:repeat]
  end

  # Removes (PERMANENTLY!) the playlist `playlist.m3u` from
  # the playlist directory
  #
  # Returns true if successful,
  # Raises a RuntimeError if the command failed
  def rm(playlist)
    send_command "rm \"#{playlist}\""
  end

  # An Alias for rm
  def remove_playlist(playlist)
    rm playlist
  end

  # Saves the current playlist to `playlist`.m3u in the
  # playlist directory
  #
  # Returns true if successful,
  # Raises a RuntimeError if the command failed
  def save(playlist)
    send_command "save \"#{playlist}\""
  end

  # Searches for any song that contains `what` in the `type` field
  # `type` can be 'title', 'artist', 'album' or 'filename'
  # Searches are NOT case sensitive
  #
  # Returns an Array of MPD::Songs,
  # Raises a RuntimeError if the command failed
  def search(type, what)
    build_songs_list(send_command("search #{type} \"#{what}\""))
  end

  # Seeks to the position `time` (in seconds) of the
  # song at `pos` in the playlist
  #
  # Returns true if successful,
  # Raises a RuntimeError if the command failed
  def seek(pos, time)
    send_command "seek #{pos} #{time}"
  end

  # Seeks to the position `time` (in seconds) of the song with
  # the id `songid`
  #
  # Returns true if successful,
  # Raises a RuntimeError if the command failed
  def seekid(songid, time)
    send_command "seekid #{songid} #{time}"
  end

  # Set the volume
  # The argument `vol` will automatically be bounded to 0 - 100
  #
  # Raises a RuntimeError if the command failed
  def volume=(vol)
    send_command "setvol #{vol}"
  end

  # Returns the volume,
  # Raises a RuntimeError if the command failed
  def volume
    status = self.status
    return status[:volume]
  end

  # Shuffles the playlist,
  # Raises a RuntimeError if the command failed
  def shuffle
    send_command :shuffle
  end

  # Returns a Hash of MPD's stats,
  # Raises a RuntimeError if the command failed
  def stats
    response = send_command :stats
    build_hash response
  end

  # Returns a Hash of the current status,
  # Raises a RuntimeError if the command failed
  def status
    response = build_hash(send_command :status)

    response.each do |key, val|
      next if IGNORE_KEYS.include? key

      # parse keys
      if STRING_KEYS.include? key
        # skip
      elsif BOOL_KEYS.include? key
        response[key] = !val.to_i.zero?
      else
        response[key] = val.to_i
      end
    end

    return response
  end

  # Stop playing
  #
  # Returns true if successful,
  # Raises a RuntimeError if the command failed
  def stop
    send_command :stop
  end

  # Returns true if the server's state is 'stop',
  # Raises a RuntimeError if the command failed
  def stopped?
    status = self.status
    return false if status.nil?
    return status[:state] == 'stop'
  end

  # Swaps the song at position `posA` with the song
  # as position `posB` in the playlist
  #
  # Returns true if successful,
  # Raises a RuntimeError if the command failed
  def swap(posA, posB)
    send_command "swap #{posA} #{posB}"
  end

  # Swaps the song with the id `songidA` with the song
  # with the id `songidB`
  #
  # Returns true if successful,
  # Raises a RuntimeError if the command failed
  def swapid(songidA, songidB)
    send_command "swapid #{songidA} #{songidB}"
  end

  # Tell the server to update the database. Optionally,
  # specify the path to update
  def update(path = nil)
    ret = ''
    if not path.nil?
      ret = send_command("update \"#{path}\"")
    else
      ret = send_command('update')
    end

    return(ret.gsub('updating_db: ', '').to_i)
  end

  # Gives a list of all outputs
  def outputs
    build_outputs_list(send_command("outputs"))
  end

  # Enables output num
  def enableoutput(num)
    send_command("enableoutput #{num.to_s}")
  end

  # Disables output num
  def disableoutput(num)
    send_command("disableoutput #{num.to_s}")
  end


  # Private Method
  #
  # Used to send a command to the server. This synchronizes
  # on a mutex to be thread safe
  #
  # Returns the server response as processed by `handle_server_response`,
  # Raises a RuntimeError if the command failed
  def send_command(command)
    raise "MPD: Not Connected to the Server" if @socket.nil?

    ret = nil

    @mutex.synchronize do
      begin
        @socket.puts command.to_s
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
      when "OK\n"
        reading = false
      when /^ACK/
        error = line
        reading = false
      when nil
        reading = false
      else
        msg += line
      end
    end

    if error.nil?
      return true if msg.empty?
      return msg
    else
      raise error.gsub( /^ACK \[(\d+)\@(\d+)\] \{(.+)\} (.+)$/, 'MPD Error #\1: \3: \4') 
    end
  end

  # Private Method
  #
  # This builds a hash out of lines returned from the server.
  # First the response is turned into an array of lines
  # then each entry is parsed so that the line is viewed as
  # "key: value"
  #
  # The end result is a hash containing the proper key/value pairs
  def build_hash(string)
    return {} if string.nil?

    hash = {}
    string.split("\n").each do |line|
      hash[line.gsub(/:.*/, '').downcase.to_sym] = line.gsub(/\A[^:]*: /, '')
    end

    return hash
  end

  # Private Method
  #
  # This is similar to build_hash, but instead of building a Hash,
  # a MPD::Song is built.
  def build_song(string)
    return nil if string.nil?

    options = build_hash(string)
    return Song.new(options)
  end

  # Private Method
  #
  # Splits the string that the server retuned at lines starting 
  # with 'file:', then uses the chunks to create MPD::Song objects.
  #
  # The end result is an Array of MPD::Songs
  def build_songs_list(string)
    return [] if string.nil?

    lines = string.split(/\n(?=file)/)
    list = lines.inject([]) do |result, chunk|
      result << build_song(chunk)
    end

    return list.compact
  end

  # Private Method
  #
  # This first creates an array of lines as returned from the server
  # Then each entry is processed and added to an Hash
  # Whenever a new 'outputid:' entry is found, the current Hash
  # is added to an array, and a new one is created
  #
  # The end result is an Array of Hashes(containing the outputs)
  def build_outputs_list(string)
    return [] if string.nil?

    list = []
    output = {}
    lines = string.split "\n"
    lines.each do |line|
      key = line.gsub(/:.*/, '')
      line.gsub!(/\A[^:]*: /, '')

      if key == 'outputid' && !output['outputid'].nil?
        list << output
      end

      output[key.downcase] = line
    end

    list << output

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
  def filter_response(string, regexp)
    list = []
    lines = string.split "\n"
    lines.each do |line|
      if line =~ regexp
        list << line.gsub(regexp, '')
      end
    end

    return list
  end

  private :send_command
  private :handle_server_response
  private :build_hash
  private :build_song
  private :build_songs_list
  private :build_outputs_list
  private :filter_response

end
