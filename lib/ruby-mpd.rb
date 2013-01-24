require 'socket'
require 'thread'

require 'ruby-mpd/exceptions'
require 'ruby-mpd/song'
require 'ruby-mpd/parser'
require 'ruby-mpd/playlist'

require 'ruby-mpd/plugins/information'
require 'ruby-mpd/plugins/playback_options'
require 'ruby-mpd/plugins/controls'
require 'ruby-mpd/plugins/queue'
require 'ruby-mpd/plugins/playlists'
require 'ruby-mpd/plugins/database'
require 'ruby-mpd/plugins/stickers'
require 'ruby-mpd/plugins/outputs'
require 'ruby-mpd/plugins/reflection'
require 'ruby-mpd/plugins/channels'

# @!macro [new] error_raise
#   @raise (see #send_command)
# @!macro [new] returnraise
#   @return [Boolean] returns true if successful.
#   @macro error_raise

# The main class/namespace of the MPD client.
class MPD
  include Parser

  include Plugins::Information
  include Plugins::PlaybackOptions
  include Plugins::Controls
  include Plugins::Queue
  include Plugins::Playlists
  include Plugins::Database
  include Plugins::Stickers
  include Plugins::Outputs
  include Plugins::Reflection
  include Plugins::Channels

  # The version of the MPD protocol the server is using.
  attr_reader :version

  # Initialize an MPD object with the specified hostname and port.
  # When called without arguments, 'localhost' and 6600 are used.
  def initialize(hostname = 'localhost', port = 6600)
    @hostname = hostname
    @port = port
    @socket = nil
    @version = nil
    @tags = nil

    @stop_cb_thread = false
    @mutex = Mutex.new
    @cb_thread = nil
    @callbacks = {}
  end

  # This will register a block callback that will trigger whenever
  # that specific event happens.
  #
  #   mpd.on :volume do |volume|
  #     puts "Volume was set to #{volume}!"
  #   end
  #
  # One can also define separate methods or Procs and whatnot,
  # just pass them in as a parameter.
  #
  #  method = Proc.new {|volume| puts "Volume was set to #{volume}!" }
  #  mpd.on :volume, &method
  #
  # @param [Symbol] event The event we wish to listen for.
  # @param [Proc, Method] block The actual callback.
  # @return [void]
  def on(event, &block)
    @callbacks[event] ||= []
    @callbacks[event].push block
  end

  # Triggers an event, running it's callbacks.
  # @param [Symbol] event The event that happened.
  # @return [void]
  def emit(event, *args)
    @callbacks[event] ||= []
    @callbacks[event].each do |handle|
      handle.call *args
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
    raise ConnectionError, 'Already connected!' if self.connected?

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

  # Check if the client is connected.
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
  # @return [Boolean] True if successfully disconnected, false otherwise.
  def disconnect
    @stop_cb_thread = true

    return false if !@socket

    @socket.puts 'close'
    @socket.close
    @socket = nil
    return true
  end

  # Kills the MPD process.
  # @macro returnraise
  def kill
    send_command :kill
  end

  # Used for authentication with the server.
  # @param [String] pass Plaintext password
  # @macro returnraise
  def password(pass)
    send_command :password, pass
  end

  # Ping the server.
  # @macro returnraise
  def ping
    send_command :ping
  end

  # Used to send a command to the server, and to recieve the reply.
  # Reply gets parsed. Synchronized on a mutex to be thread safe.
  #
  # Can be used to get low level direct access to MPD daemon. Not
  # recommended, should be just left for internal use by other
  # methods.
  #
  # @return (see #handle_server_response)
  # @raise [MPDError] if the command failed.
  def send_command(command, *args)
    raise ConnectionError, "Not connected to the server!" if @socket.nil?

    @mutex.synchronize do
      begin
        @socket.puts convert_command(command, *args)
        response = handle_server_response
        return parse_response(command, response)
      rescue Errno::EPIPE
        @socket = nil
        raise ConnectionError, 'Broken pipe (got disconnected)'
      end
    end
  end

  private

  # Handles the server's response (called inside {#send_command}).
  # Repeatedly reads the server's response from the socket.
  #
  # @return (see Parser#build_response)
  # @return [true] If "OK" is returned.
  # @raise [MPDError] If an "ACK" is returned.
  def handle_server_response
    return if @socket.nil?

    msg = ''
    while true
      case line = @socket.gets
      when "OK\n", nil
        break
      when /^ACK/
        error = line
        break
      else
        msg << line
      end
    end

    if !error
      return true if msg.empty?
      return msg
    else
      err = error.match(/^ACK \[(?<code>\d+)\@(?<pos>\d+)\] \{(?<command>.*)\} (?<message>.+)$/)
      raise SERVER_ERRORS[err[:code].to_i], "[#{err[:command]}] #{err[:message]}"
    end
  end

  SERVER_ERRORS = {
    1 => NotListError,
    2 => ServerArgumentError,
    3 => IncorrectPassword,
    4 => PermissionError,
    5 => ServerError,

    50 => NotFound,
    51 => PlaylistMaxError,
    52 => SystemError,
    53 => PlaylistLoadError,
    54 => AlreadyUpdating,
    55 => NotPlaying,
    56 => AlreadyExists
  }

end
