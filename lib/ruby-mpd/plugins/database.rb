class MPD
  module Plugins
    # Commands for interacting with the music database.
    #
    # Changes: listallinfo -> songs, searchaddpl in MPD::Playlist#searchadd
    # search merges search, find, searchadd and findadd
    module Database

      # Counts the number of songs and their total playtime
      # in the db matching, matching the searched tag exactly.
      # @return [Hash] a hash with +songs+ and +playtime+ keys.
      def count(type, what)
        send_command :count, type, what
      end

      # List all tags of the specified type.
      # Type can be any tag supported by MPD or +:file+.
      # If type is 'album' then arg can be a specific artist to list the albums for
      #
      # @return [Array<String>]
      def list(type, arg = nil)
        send_command :list, type, arg
      end

      # listall

      # List all of the songs in the database starting at path.
      # If path isn't specified, the root of the database is used
      #
      # @return [Array<MPD::Song>]
      def songs(path = nil)
        build_songs_list send_command(:listallinfo, path)
      end

      # lsinfo

      # Searches for any song that contains +what+ in the +type+ field.
      # Searches are case insensitive by default, however you can enable
      # it using the third argument.
      #
      # Options:
      # * *add*: Add the search results to the queue.
      # * *case_sensitive*: Make the query case sensitive.
      #
      # @param [Symbol] type Can be any tag supported by MPD, or one of the two special
      #   parameters: +:file+ to search by full path (relative to database root),
      #   and +:any+ to match against all available tags.
      # @param [Hash] A hash of options.
      # @return [Array<MPD::Song>] Songs that matched.
      # @return [true] if +:add+ is enabled.
      def search(type, what, options = {})
        if options[:add]
          command = options[:case_sensitive] ? :findadd : :searchadd
        else
          command = options[:case_sensitive] ? :find : :search
        end

        build_songs_list send_command(command, type, what)
      end

      # Tell the server to update the database. Optionally,
      # specify the path to update.
      #
      # @return [Integer] Update job ID
      def update(path = nil)
        send_command :update, path
      end

      # Same as {#update}, but also rescans unmodified files.
      #
      # @return [Integer] Update job ID
      def rescan(path = nil)
        send_command :rescan, path
      end

    end
  end
end