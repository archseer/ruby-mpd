class MPD
  module Plugins
    # These commands manipulate the current playlist, what's playing now.
    # For a distinction between this and other playlists, this is called
    # queue.
    module Queue

      # List the current playlist/queue.
      # An Integer or Range can be used to limit the information returned
      # to a specific subset.
      #
      # @return [MPD::Song, Array<MPD::Song>] Array of songs in the queue
      # or a single song.
      def queue(limit=nil)
        build_songs_list send_command(:playlistinfo, limit)
      end

      # Add the file _path_ to the queue. If path is a directory,
      # it will be added *recursively*.
      # @macro returnraise
      def add(path)
        send_command :add, path
      end

      # Adds a song to the queue (*non-recursive*) and returns the song id.
      # Optionally, one can specify the position on which to add the song (since MPD 0.14).
      # @return [Integer] id of the song that was added.
      def addid(path, pos=nil)
        send_command :addid, pos
      end

      # Clears the current queue.
      # @macro returnraise
      def clear
        send_command :clear
      end

      # Deletes the song from the queue.
      #
      # Since MPD 0.15 a range can also be passed. Songs with positions within range will be deleted.
      # @param [Integer, Range] pos Song with position in the queue will be deleted,
      # if range is passed, songs with positions within range will be deleted.
      # @param [Hash] pos :id to specify the song ID to delete instead of position.
      # @macro returnraise
      def delete(pos)
        if pos.is_a?(Hash) 
          if pos[:id]
            send_command :deleteid, pos[:id]
          else
            raise ArgumentError, 'Only :id key is allowed!'
          end
        else
          send_command :delete, pos
        end
      end

      # Move the song at +from+ to +to+ in the queue.
      # * Since 0.14, +to+ can be a negative number, which is the offset
      #   of the song from the currently playing (or to-be-played) song.
      #   So -1 would mean the song would be moved to be the next song in the queue.
      #   Moving a song to -queue.length will move it to the song _before_ the current
      #   song on the queue; so this will work for repeating playlists, too.
      # * Since 0.15, +from+ can be a range of songs to move.
      # @param [Hash] from :id to specify the song ID to move instead of position.
      # @macro returnraise
      def move(from, to)
        if pos.is_a?(Hash) 
          if pos[:id]
            send_command :moveid, pos[:id], to
          else
            raise ArgumentError, 'Only :id key is allowed!'
          end
        else
          send_command :move, from, to
        end
      end

      # Returns the song with the +songid+ in the playlist,
      # @return [MPD::Song]
      def song_with_id(songid)
        Song.new send_command(:playlistid, songid)
      end

      # Searches for songs in the queue matched by the what
      # argument. Case insensitive by default.
      #
      # @param [Symbol] type Can be any tag supported by MPD, or one of the two special
      #   parameters: +:file+ to search by full path (relative to database root),
      #   and +:any+ to match against all available tags.
      #
      # @param [Hash] options Use +:case_sensitive+ to make the query case sensitive.
      # @return [Array<MPD::Song>] Songs that matched.
      def queue_search(type, what, options = {})
        command = options[:case_sensitive] ? :playlistfind : :playlistsearch
        build_songs_list send_command(command, type, what)
      end

      # List the changes since the specified version in the queue.
      # @return [Array<MPD::Song>]
      def queue_changes(version)
        build_songs_list send_command(:plchanges, version)
      end

      # plchangesposid

      # Set the priority of the specified songs. A higher priority means that it will be played
      # first when "random" mode is enabled.
      # @param [Integer] priority An integer between 0 and 255. The default priority of new songs is 0.
      # @param [Integer] pos A specific position.
      # @param [Range] pos A range of positions.
      # @param [Hash] pos :id to specify the song ID to move instead of position.
      def song_priority(priority, pos)
        if pos.is_a?(Hash) 
          if pos[:id]
            send_command :prioid, priority, pos[:id]
          else
            raise ArgumentError, 'Only :id key is allowed!'
          end
        else
          send_command :prio, priority, pos
        end
      end

      # Shuffles the queue.
      # Optionally, a Range can be used to shuffle a specific subset.
      # @macro returnraise
      def shuffle(range=nil)
        send_command :shuffle, range
      end

      # Swaps the song at position +posA+ with the song
      # as position +posB+ in the queue.
      # @macro returnraise
      def swap(posA, posB)
        send_command :swap, posA, posB
      end

      # Swaps the positions of the song with the id +songidA+
      # with the song with the id +songidB+ in the queue.
      # @macro returnraise
      def swapid(songidA, songidB)
        send_command :swapid, songidA, songidB
      end

      # Saves the current playlist/queue to +playlist+.m3u in the
      # playlist directory.
      # @macro returnraise
      def save(playlist)
        send_command :save, playlist
      end

    end
  end
end