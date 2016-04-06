module MPD::Plugins

  # Batch send multiple commands at once for speed.
  module CommandList
    # Send multiple commands at once.
    #
    # By default, any response from the server is ignored (for speed).
    # To get results, pass +{results:true}+ to the method.
    #
    # Note that each supported command has no return value inside the block.
    # Instead, the block itself returns the array of results.
    #
    # @param [Symbol] response_type the type of responses desired.
    # @return [nil] default behavior.
    # @return [Array] if +results+ is +true+.
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
    #   ids = @mpd.command_list(results:true){ my_songs.each{ |song| addid(song) } }
    #   #=> [799,800,801,802,803]
    #
    # @example Finding songs matching various genres
    #   results = @mpd.command_list(results:true) do
    #     where genre:'Alternative Rock'
    #     where genre:'Alt. Rock'
    #     where genre:'alt-rock'
    #   end
    #   p results.class       #=> Array (One result for each command that gives results)
    #   p results.length      #=> 3     (One for each command that returns results)
    #   p results.first.class #=> Array (Each `where` command returns its own results)
    #
    #
    # @example Using playlists inside a command list
    #   def shuffle_playlist( playlist )
    #     song_count = @mpd.send_command(:listplaylist, playlist.name).length
    #     @mpd.command_list do
    #       (song_count-1).downto(1){ |i| playlist.move i, rand(i+1) }
    #     end
    #   end
    #     
    # 
    # @see CommandList::Commands CommandList::Commands for a list of supported commands.
    def command_list(opts={},&commands)
      @mutex.synchronize do
        begin
          @command_list_commands = []
          socket.puts( opts[:results] ? "command_list_ok_begin" : "command_list_begin" )
          @command_list_active = true
          CommandList::Commands.new(self).instance_eval(&commands)
          @command_list_active = false
          socket.puts "command_list_end"

          # clear the response from the socket, even if we will not parse it
          response = handle_server_response || ""

          parse_command_list( @command_list_commands, response ) if opts[:results]
        rescue Errno::EPIPE
          reconnect
          retry
        ensure
          @command_list_commands = nil
          @command_list_active = false
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
    include MPD::Plugins::Playlists

    private
      def send_command(command,*args)
        @mpd.send_command(command,*args)
      end
  end
end