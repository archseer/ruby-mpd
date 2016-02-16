require 'ruby-mpd'

module MPD::Plugins

  # Batch send multiple commands at once for speed.
  module CommandList
    # Send multiple commands at once.
    #
    # By default, any response from the server is ignored (for speed).
    # To get results, pass `response_type` as one of the following options:
    #
    #  * `:hash`   — a single hash of return values; multiple return values for the same key are grouped in an array
    #  * `:values` — an array of individual values
    #  * `:hashes` — an array of hashes (where value boundaries are guessed based on the first result)
    #  * `:songs`  — an array of Song instances from the results
    #  * `:playlists` - an array of Playlist instances from the results
    #
    # Note that each supported command has no return value inside the block.
    # Instead, the block itself returns the array of results.
    #
    # @param [Symbol] response_type the type of responses desired.
    # @return [nil] default behavior.
    # @return [Array] if `response_type` is `:values`, `:hashes`, `:songs`, or `:playlists`.
    # @return [Hash] if `response_type` is `:hash`.
    #
    # @example Simple batched control commands
    #   @mpd.command_list do
    #     stop
    #     shuffle
    #     save "shuffled"
    #   end
    #
    # @example Adding songs to the queue, ignoring the response
    #   @mpd.command_list do
    #     my_songs.each do |song|
    #       add(song)
    #     end
    #   end
    #
    # @example Adding songs to the queue and getting the song ids
    #   ids = @mpd.command_list(:values){ my_songs.each{ |song| addid(song) } }
    #   #=> [799,800,801,802,803]
    #   
    #   ids = @mpd.command_list(:hashes){ my_songs.each{ |song| addid(song) } }
    #   #=> [ {:id=>809}, {:id=>810}, {:id=>811}, {:id=>812}, {:id=>813} ]
    #
    #   ids = @mpd.command_list(:hash){   my_songs.each{ |song| addid(song) } }
    #   #=> { :id=>[804,805,806,807,808] }
    #   
    # @example Finding songs matching various genres
    #   songs = @mpd.command_list(:songs) do
    #     where genre:'Alternative Rock'
    #     where genre:'Alt. Rock'
    #     where genre:'alt-rock'
    #   end
    #
    # @see CommandList::Commands CommandList::Commands for a list of supported commands.
    def command_list(response_type=nil,&commands)
      @mutex.synchronize do
        begin
          socket.puts "command_list_begin"
          CommandList::Commands.new(self).instance_eval(&commands)
          socket.puts "command_list_end"

          # clear the response from the socket, even if we will not parse it
          response = handle_server_response || ""

          case response_type
          when :values    then response.lines.map{ |line| parse_line(line).last }
          when :hash      then build_hash(response)
          when :hashes    then build_response(:commandlist,response,true)
          when :songs     then build_songs_list parse_response(:listallinfo,response)
          when :playlists then parse_response(:listplaylists,response).map{ |h| MPD::Playlist.new(self, h) }
          end
        rescue Errno::EPIPE
          reconnect
          retry
        end
      end
    end
  end

  class CommandList::Commands
    def initialize(mpd)
      @mpd = mpd
    end

    include MPD::Plugins::Controls
    include MPD::Plugins::PlaybackOptions
    include MPD::Plugins::Queue
    include MPD::Plugins::Stickers
    include MPD::Plugins::Database

    private
      def send_command(command,*args)
        @mpd.send(:socket).puts @mpd.send(:convert_command, command, *args)
      end
  end
end