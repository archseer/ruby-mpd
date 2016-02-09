require 'ruby-mpd'

module MPD::Plugins

  # Batch send multiple commands at once for speed.
  module CommandList
    # Send multiple commands at once.
    #
    # By default any response from the server is ignored (for speed).
    # To get results, pass `results:true` as an option to the method.
    #
    # Note that each supported command has no return value inside the block.
    # Instead, the block itself returns an array of results.
    #
    # @param [Hash] opts the options to create a message with.
    # @option opts [Boolean] :results Set to true to process the server response (for speed).
    # @return [nil] by default, or if no commands have any results.
    # @return [Array] of command results if `results:true` is supplied (types may vary).
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
    #   ids = @mpd.command_list(results:true) do
    #     my_songs.each{ |song| addid(song) }
    #   end
    #
    # @see CommandList::Commands CommandList::Commands for a list of supported commands.
    def command_list(opts={},&commands)
      @mutex.synchronize do
        begin
          socket.puts "command_list_begin"
          CommandList::Commands.new(self).instance_eval(&commands)
          socket.puts "command_list_end"
          response = handle_server_response
          parse_response(:commandlist, response) if opts[:results]
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