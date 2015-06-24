require 'socket'
require 'thread'

require 'ruby-mpd/version'
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

require 'ruby-mpd/callback_processor'

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

  attr_reader :version, :hostname, :port

  # Initialize an MPD object with the specified hostname and port.
  # When called without arguments, 'localhost' and 6600 are used.
  #
  # When called with +callbacks: true+ as an optional argument,
  # callbacks will be enabled by starting a separate polling thread.
  #
  # @param [String] hostname Hostname of the daemon
  # @param [Integer] port Port of the daemon
  # @param [Hash] opts Optional parameters. Currently accepts +callbacks+
  def initialize(hostname = 'localhost', port = 6600, opts = {})
    @hostname = hostname
    @port = port
    @options = {callbacks: false}.merge(opts)
    @password = opts.delete(:password) || nil
    reset_vars

    @mutex = Mutex.new
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
    (@callbacks[event] ||= []).push block
  end

  # Triggers an event, running it's callbacks.
  # @param [Symbol] event The event that happened.
  # @return [void]
  def emit(event, *args)
    return unless @callbacks[event]
    @callbacks[event].each { |handle| handle.call(*args) }
  end

  # Connect to the daemon.
  #
  # When called without any arguments, this will just connect to the server
  # and wait for your commands.
  #
  # @return [true] Successfully connected.
  # @raise [MPDError] If connect is called on an already connected instance.
  def connect
    raise ConnectionError, 'Already connected!' if connected?

    # by protocol, we need to get a 'OK MPD <version>' reply
    # should we fail to do so, the connection was unsuccessful
    unless response = socket.gets
      reset_vars
      raise ConnectionError, 'Unable to connect (possibly too many connections open)'
    end

    authenticate
    @version = response.chomp.gsub('OK MPD ', '') # Read the version

    start_callback_thread! if @options[:callbacks]
    return true
  end

  # Check if the client is connected.
  #
  # @return [Boolean] True only if the server responds otherwise false.
  def connected?
    return false unless @socket
    send_command(:ping) rescue false
  end

  # Disconnect from the MPD daemon. This has no effect if the client is not
  # connected. Reconnect using the {#connect} method. This will also stop
  # the callback thread, thus disabling callbacks.
  # @return [Boolean] True if successfully disconnected, false otherwise.
  def disconnect
    @cb_thread[:stop] = true if @cb_thread

    return false unless @socket

    begin
      @socket.puts 'close'
      @socket.close
    rescue Errno::EPIPE
      # socket was forcefully closed
    ensure
      @socket = nil
    end

    reset_vars
    return true
  end

  # Attempts to reconnect to the MPD daemon.
  # @return [Boolean] True if successfully reconnected, false otherwise.
  def reconnect
    disconnect
    connect
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

  def authenticate
    send_command(:password, @password) if @password
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
    raise ConnectionError, "Not connected to the server!" unless @socket

    @mutex.synchronize do
      begin
        @socket.puts convert_command(command, *args)
        response = handle_server_response
        return parse_response(command, response)
      rescue Errno::EPIPE
        reconnect
        retry
      end
    end
  end

  private

  # Initialize instance variables on new object, or on disconnect.
  def reset_vars
    @socket = nil
    @version = nil
    @tags = nil
  end

  # Constructs a callback loop thread and/or resumes it.
  # @return [Thread]
  def start_callback_thread!
    Thread::abort_on_exception = true
    processor = CallbackProcessor.new(self)

    Thread.new do
      loop do
        processor.process!
        sleep 0.1
      end
    end
  end

  # Handles the server's response (called inside {#send_command}).
  # Repeatedly reads the server's response from the socket.
  #
  # @return (see Parser#build_response)
  # @return [true] If "OK" is returned.
  # @raise [MPDError] If an "ACK" is returned.
  def handle_server_response
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

    return msg unless error
    err = error.match(/^ACK \[(?<code>\d+)\@(?<pos>\d+)\] \{(?<command>.*)\} (?<message>.+)$/)
    raise SERVER_ERRORS[err[:code].to_i], "[#{err[:command]}] #{err[:message]}"
  end

  def socket
    @socket ||= File.exists?(@hostname) ? UNIXSocket.new(@hostname) : TCPSocket.new(@hostname, @port)
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
