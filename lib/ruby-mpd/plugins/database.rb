class MPD
  module Plugins
    # Commands for interacting with the music database.
    module Database

      # Counts the number of songs and their total playtime
      # in the db matching, matching the searched tag exactly.
      #
      # If you need a count on the entire database, look at
      # {#stats #stats}.
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

      # List all of the files in the database, starting at path.
      # If path isn't specified, the root of the database is used.
      #
      # @return [Hash<String>] hash with array keys :file, :directory and :playlist.
      def files(path = nil)
        send_command :listall, path
      end

      # List all of the songs in the database starting at path.
      # If path isn't specified, the root of the database is used
      #
      # @return [Array<MPD::Song>]
      def songs(path = nil)
        build_songs_list send_command(:listallinfo, path)
      end

      # lsinfo - Clients that are connected via UNIX domain socket may use this
      # command to read the tags of an arbitrary local file (URI beginning with "file:///").

      # Searches for any song that contains +what+ in the +type+ field.
      # Searches are case insensitive by default, however you can enable
      # it using the third argument.
      #
      # @deprecated Use {#where} instead.
      #
      # Options:
      # * *add*: Add the search results to the queue.
      # * *case_sensitive*: Make the query case sensitive.
      #
      # @param [Symbol] type Can be any tag supported by MPD, or one of the two special
      #   parameters: +:file+ to search by full path (relative to database root),
      #   and +:any+ to match against all available tags.
      # @param [Hash] options A hash of options.
      # @return [Array<MPD::Song>] Songs that matched.
      # @return [true] if +:add+ is enabled.
      def search(type, what, options = {})
        warn "MPD#search is deprecated! Use MPD#where instead."
        options[:strict] = options[:case_sensitive] # transparently upgrade renamed option
        where({type => what}, options)
      end

      # Searches the database for any songs that match the specified parameters.
      # Searching is *loose* (case insensitive and allow partial matching) by
      # default.
      #
      # The search keys can be any of the tags supported by MPD, or one of the
      # two special parameters: +:file+ to search by full path (relative to
      # database root), and +:any+ to match against all available tags.
      #
      #    mpd.where(artist: "DJ Shadow", album: "Endtroducing.....")
      #
      # A hash of options can be passed as a last parameter:
      #
      #    mpd.where({artist: "Nujabes", album: "Modal Soul"}, {add: true})
      #
      # Options:
      # * *add*: Add search results to the queue.
      # * *strict*: Search will be *case sensitive* and allow only *full matches*.
      #
      # @param [Hash] params A hash of search parameters.
      # @param [Hash] options A hash of options.
      # @return [Array<MPD::Song>] Songs that matched.
      # @return [true] if +:add+ is enabled.
      def where(params, options = {})
        if options[:add]
          command = options[:strict] ? :findadd : :searchadd
        else
          command = options[:strict] ? :find : :search
        end

        response = send_command(command, params)
        case response
        when true then true
        when nil  then nil
        else
          build_songs_list response
        end
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
      # @return (see #update)
      def rescan(path = nil)
        send_command :rescan, path
      end

      # unofficial

      # List all of the directories in the database, starting at path.
      # If path isn't specified, the root of the database is used.
      #
      # @return [Array<String>] Array of directory names
      def directories(path = nil)
        return files(path)[:directory]
      end

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

      # List all of the songs by an artist.
      #
      # @return [Array<MPD::Song>]
      def songs_by_artist(artist)
        where(artist: artist)
      end

    end
  end
end
