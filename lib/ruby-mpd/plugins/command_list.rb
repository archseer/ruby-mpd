module MPD::Plugins

  # Batch send multiple commands at once for speed.
  module CommandList
    # Send multiple commands at once.
    #
    # By default, any response from the server is ignored (for speed).
    # To get results, pass +response_type+ as one of the following options:
    #
    # * +:hash+   — a single hash of return values; multiple return values for the same key are grouped in an array
    # * +:values+ — an array of individual values
    # * +:hashes+ — an array of hashes (where value boundaries are guessed based on the first result)
    # * +:songs+  — an array of Song instances from the results
    # * +:playlists+ - an array of Playlist instances from the results
    #
    # Note that each supported command has no return value inside the block.
    # Instead, the block itself returns the array of results.
    #
    # @param [Symbol] response_type the type of responses desired.
    # @return [nil] default behavior.
    # @return [Array] if +response_type+ is +:values+, +:hashes+, +:songs+, or +:playlists+.
    # @return [Hash] if +response_type+ is +:hash+.
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
          when :playlists then build_playlists  parse_response(:listplaylists,response)
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

    # List all of the playlists in the database
    def playlists
      send_command(:listplaylists)
    end

    # Fetch full details for all songs in a playlist
    # @param [String,Playlist] playlist The string name (or playlist object) to get songs for.
    def songs_in_playlist(playlist)
      send_command(:listplaylistinfo, playlist)
    end

    # Fetch file names only for all songs in a playlist
    # @param [String,Playlist] playlist The string name (or playlist object) to get files for.
    def files_in_playlist(playlist)
      send_command(:listplaylist, playlist)
    end

    # Load the playlist's songs into the queue.
    #
    # Since MPD v0.17 a range can be passed to load only a part of the playlist.
    # @param [String,Playlist] playlist The string name (or playlist object) to load songs from.
    # @param [Range] range The index range of songs to add.
    def load_playlist(playlist, range=nil)
      send_command :load, playlist, range
    end

    # Add a song to the playlist.
    # @param [String,Playlist] playlist The string name (or playlist object) to add to.
    # @param [String,Song] song The string uri (or song object) to add to the playlist
    def add_to_playlist(playlist, song)
      send_command :playlistadd, playlist, song
    end

    # Search for any song that contains +value+ in the +tag+ field
    # and add them to a playlist.
    # Searches are *NOT* case sensitive.
    #
    # @param [String,Playlist] playlist The string name (or playlist object) to add to.
    # @param [Symbol] tag Can be any tag supported by MPD, or one of the two special
    #   parameters: +:file+ to search by full path (relative to database root),
    #   and +:any+ to match against all available tags.
    # @param [String] value The string to search for.
    def searchadd_to_playlist(playlist, tag, value)
      send_command :searchaddpl, playlist, tag, value
    end

    # Remove all songs from a playlist.
    # @param [String,Playlist] playlist The string name (or playlist object) to clear.
    def clear_playlist(playlist)
      send_command :playlistclear, playlist
    end

    # Delete song at +index+ from a playlist.
    # @param [String,Playlist] playlist The string name (or playlist object) to affect.
    # @param [Integer] index The index of the song to remove.
    def remove_from_playlist(playlist, index)
      send_command :playlistdelete, playlist, index
    end

    # Move a song with +song_id+ in a playlist to a new +index+.
    # @param [String,Playlist] playlist The string name (or playlist object) to affect.
    # @param [Integer] songid The +id+ of the song to move.
    # @param [Integer] index The index to move the song to.
    def reorder_playlist(playlist, song_id, index)
      send_command :playlistmove, playlist, song_id, songpos
    end

    # Rename a playlist to +new_name+.
    # @param [String,Playlist] playlist The string name (or playlist object) to rename.
    # @param [String] new_name The new name for the playlist.
    def rename_playlist(playlist,new_name)
      send_command :rename, playlist, new_name
    end

    # Delete a playlist from the disk.
    # @param [String,Playlist] playlist The string name (or playlist object) to delete.
    def destroy_playlist(playlist)
      send_command :rm, playlist
    end

    private
      def send_command(command,*args)
        @mpd.send(:socket).puts @mpd.send(:convert_command, command, *args)
      end
  end
end