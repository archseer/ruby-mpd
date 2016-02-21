require 'fileutils' # used for mkdir_p
require 'digest'    # used to generate unique file names

# A library for testing socket-based applications.
#
# Allows you to create a socket that records +puts+ commands
# and uses those to decide the (pre-recorded) responses to
# yield for subsequent calls to +gets+.
module SocketSpoof
  # The line in each recording file separating commands and responses
  SPLITTER = "--putsabove--getsbelow--\n"

  # Socket wrapper that generates 'recording' files consumed
  # by SocketSpoof::Player.
  #
  # To use, replace your own socket with a call to:
  #
  #     @socket = SocketSpoof::Recorder.new( real_socket )
  #
  # This will (by default) create a directory named "socket_recordings"
  # and create files within there for each sequence of +puts+ followed
  # by one or more gets.
  class Recorder
    # @param socket [Socket] The real socket to use for communication.
    # @param directory [String] The directory to store recording files in.
    def initialize(socket,directory:"socket_recordings")
      @socket   = socket
      @commands = []
      FileUtils.mkdir_p( @directory=directory )
    end
    def puts(*a)
      @socket.puts(*a).tap{ @commands.concat(a.empty? ? [nil] : a) }
    end
    def gets
      @socket.gets.tap do |response|
        unless @file && @commands.empty?
          @file = File.join( @directory, Digest::SHA256.hexdigest(@commands.inspect) )
          File.open(@file,'w'){ |f| f.puts(@commands); f<<SPLITTER }
          @commands=[]
        end
        File.open(@file,'a'){ |f| f.puts response }
      end
    end
    def method_missing(*a)
      @socket.send(*a)
    end
  end

  # Socket stand-in using files on disk to send responses.
  #
  # A SocketSpoot::Player uses a sequence of calls to +puts+ along
  # with playback files to decide what to send back when +gets+
  # is called.
  #
  # Simply replace your normal socket instance with a Player, and
  # point that player to a directory where recording files are stored.
  #
  #    @socket = SocketSpoof::Player.new( directory:'test_data' )
  #
  # The name of each recording file in the directory does not matter;
  # name them as you like to make them easier to find.
  # The format of the files must have zero or more lines of command
  # strings, followed by the +SPLITTER+ string, followed by zero or
  # more lines of response strings. For example:
  #
  #    prepare
  #    listplaylists
  #    --putsabove--getsbelow--
  #    playlist: Mix Rock Alternative Electric
  #    Last-Modified: 2015-11-23T15:58:51Z
  #    playlist: Enya-esque
  #    Last-Modified: 2015-11-18T16:19:12Z
  #    playlist: RecentNice
  #    Last-Modified: 2015-12-01T15:52:38Z
  #    playlist: Dancetown
  #    Last-Modified: 2015-11-18T16:19:26Z
  #    playlist: Piano
  #    Last-Modified: 2015-11-18T16:17:13Z
  #    OK
  #
  # With the above file in place in the directory:
  #
  #    @socket = SocketSpoof::Player.new
  #    @socket.puts "prepare"
  #    @socket.puts "listplaylists"
  #    loop do
  #      case response=@socket.gets
  #      when "OK\n",nil then puts "all done!"
  #      else                 puts response
  #    end
  #
  # ...will output all lines from the file. As with a normal
  # socket, the call to +gets+ will include a newline at the end
  # of the response.
  #
  # If your code calls +gets+ before it ever calls +puts+, you
  # will need a file with no content above the +SPLITTER+ line.
  #
  # To verify that your library sent the commands that you expected,
  # the +last_messages+ method returns an array of strings sent to
  # +puts+ since the last call to +gets+.
  class Player
    # @param directory [String] the name of the directory to find recordings in; defaults to "socket_recordings".
    # @param auto_update [Boolean] whether the directory should be rescanned (slow!) before each call to +gets+; defaults to +false+.
    def initialize(directory:"socket_recordings",auto_update:false)
      @commands = []
      FileUtils.mkdir_p( @directory=directory )
      @auto_update = auto_update
      @response_line = -1
      rescan
    end

    # Find out what messages were last sent to the socket.
    #
    # Returns an array of strings sent to +puts+ since the
    # last time +gets+ was called on the socket.
    # @return [Array<String>] messages previously sent through +puts+
    def last_messages
      @current
    end
    def puts(*a)
      @commands.concat(a.empty? ? [nil] : a)
      @response_line = -1
      nil # match the return value of IO#puts, just in case
    end
    def gets
      rescan if @auto_update
      @current,@commands=@commands,[] unless @commands.empty?
      if @responses[@current]
        @responses[@current][@response_line+=1]
      else
        raise "#{self.class} has no recording for #{@current}"
      end
    end
    def method_missing(*a)
      raise "#{self.class} has no support for #{a.shift}(#{a.map(&:inspect).join(', ')})"
    end

    private
    def rescan
      @responses = {}
      Dir[File.join(@directory,'*')].each do |file|
        commands,responses = File.open(file,'r:utf-8',&:read).split(SPLITTER,2)
        if responses
          @responses[commands.split("\n")] = responses.lines.to_a
        else
          warn "#{self.class} ignoring #{file} because it does not appear to have #{SPLITTER.inspect}."
        end
      end
    end
  end
end