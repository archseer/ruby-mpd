require 'socket'
require 'thread'

require_relative 'song'
require_relative 'parser'

require_relative 'playlist'

require_relative 'plugins/information'
require_relative 'plugins/playback_options'
require_relative 'plugins/controls'
require_relative 'plugins/queue'
require_relative 'plugins/playlists'
require_relative 'plugins/stickers'
require_relative 'plugins/outputs'
require_relative 'plugins/reflection'
require_relative 'plugins/channels'

# TODO: object oriented: make playlist commands in a
# playlist object and song commands and dir commands
# in MPD::Song, MPD::Directory.

# TODO: Namespace queue?

# manual pages todo:
# Querying MPD's status -> idle
# Playback options -> mixrampdb, mixrampdelay
# The current playlist
# The music database
# Stickers -> improve implementation
# Client to client -> improve implementation

# todo: command list as a do block
# mpd.command_list do
#   volume 10
#   play xyz
# end

# error codes stored in ack.h

# TODO:
# 0.15
#  - added the "findadd" command
#  - allow changing replay gain mode on-the-fly
# ver 0.17 (2012/06/27)
#  - new commands "searchadd", "searchaddpl"

# @!macro [new] error_raise
#   @raise (see #send_command)
# @!macro [new] returnraise
#   @return [Boolean] returns true if successful.
#   @macro error_raise

class MPD

  # Standard MPD error.
  class MPDError < StandardError; end

  include Parser

  include Plugins::Information
  include Plugins::PlaybackOptions
  include Plugins::Controls
  include Plugins::Queue
  include Plugins::Playlists
  include Plugins::Stickers
  include Plugins::Outputs
  include Plugins::Reflection
  include Plugins::Channels
  
  # The version of the MPD protocol the server is using.
  attr_reader :version
  # A list of tags MPD accepts.
  attr_reader :tags
 
  # Initialize an MPD object with the specified hostname and port.
  # When called without arguments, 'localhost' and 6600 are used.
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
  # that specific event happens.
  #
  #   mpd.on :volume do |volume|
  #     puts "Volume was set to #{volume}"!
  #   end
  #
  # One can also define separate methods or Procs and whatnot,
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
  # @return [true] Successfully connected.
  # @raise [MPDError] If connect is called on an already connected instance.
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

          # @todo Move into status[:connection]?
          if connected != c
            connected = c
            emit(:connection, connected)
          end

          status[:time] = [nil, nil] if !status[:time] # elapsed, total
          status[:audio] = [nil, nil, nil] if !status[:audio] # samp, bits, chans

          status.each do |key, val|
            next if val == old_status[key] # skip unchanged keys

            if key == :song
              emit(:song, mpd.current_song)
            else # convert arrays to splat arguments
              val.is_a?(Array) ? emit(key, *val) : emit(key, val) 
            end
          end
          
          old_status = status
          sleep 0.1

          if !connected
            sleep 2
            unless @stop_cb_thread
              mpd.connect rescue nil
            end
          end
        end
      }
    end

    return true
  end

  # Check if the client is connected
  #
  # @return [Boolean] True only if the server responds otherwise false.
  def connected?
    return false if !@socket

    ret = send_command(:ping) rescue false
    return ret
  end

  # Disconnect from the MPD daemon. This has no effect if the client is not
  # connected. Reconnect using the {#connect} method. This will also stop
  # the callback thread, thus disabling callbacks.
  def disconnect
    @stop_cb_thread = true

    return if @socket.nil?

    @socket.puts 'close'
    @socket.close
    @socket = nil
  end

  # Kills the MPD process.
  # @macro returnraise
  def kill
    send_command :kill
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

  ###--- OTHER ---###

  # Lists all of the albums in the database.
  # The optional argument is for specifying an artist to list 
  # the albums for
  #
  # @return [Array<String>] An array of album names.
  def albums(artist = nil)
    list :album, artist
  end

  # Lists all of the artists in the database.
  #
  # @return [Array<String>] An array of artist names.
  def artists
    list :artist
  end

  # List all of the directories in the database, starting at path.
  # If path isn't specified, the root of the database is used
  #
  # @return [Array<String>] Array of directory names
  def directories(path = nil)
    response = send_command :listall, path
    return response[:directory]
  end

  # List all of the files in the database, starting at path.
  # If path isn't specified, the root of the database is used
  #
  # @return [Array<String>] Array of file names
  def files(path = nil)
    response = send_command(:listall, path)
    return response[:file]
  end

  # List all of the songs by an artist.
  #
  # @return [Array<MPD::Song>]
  def songs_by_artist(artist)
    find :artist, artist
  end

  # Used to send a command to the server. This synchronizes
  # on a mutex to be thread safe
  #
  # @return (see #handle_server_response)
  # @raise [MPDError] if the command failed.
  def send_command(command, *args)
    raise MPDError, "Not Connected to the Server" if @socket.nil?

    @mutex.synchronize do
      begin
        @socket.puts convert_command(command, *args)
        return handle_server_response
      rescue Errno::EPIPE
        @socket = nil
        raise MPDError, 'Broken Pipe (Disconnected)'
      end
    end
  end

  private # Private Methods below

  # Handles the server's response (called inside {#send_command}).
  # Repeatedly reads the server's response from the socket and
  # processes the output.
  #
  # @return (see Parser#build_response)
  # @return [true] If "OK" is returned.
  # @raise [MPDError] If an "ACK" is returned.
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
      err = error.match(/^ACK \[(?<code>\d+)\@(?<pos>\d+)\] \{(?<command>.*)\} (?<message>.+)$/)
      raise MPDError, "#{err[:code]}: #{err[:command]}: #{err[:message]}"
    end
  end

end
