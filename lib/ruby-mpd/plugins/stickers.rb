class MPD
  module Plugins
    # "Stickers" are pieces of information attached to existing MPD objects
    # (e.g. song files, directories, albums). Clients can create arbitrary
    # name/value pairs. MPD itself does not assume any special meaning in them.
    #
    # The goal is to allow clients to share additional (possibly dynamic) information
    # about songs, which is neither stored on the client (not available to other clients),
    # nor stored in the song files (MPD has no write access).
    #
    # Client developers should create a standard for common sticker names, to ensure
    # interoperability.
    #
    # Objects which may have stickers are addressed by their object type ("song" for song objects)
    # and their URI (the path within the database for songs).
    module Stickers

      # seems that type is always :song, supposedly directory and
      # playlist too "(e.g. song files, directories, albums)"

      # Reads a sticker value for the specified object.
      # @return [String] The value of the sticker.
      def get_sticker(type, uri, name)
        send_command( :sticker, :get, type, uri, name ).split('=',2).last
      end

      # Adds a sticker value to the specified object. If a sticker
      # item with that name already exists, it is replaced.
      def set_sticker(type, uri, name, value)
        send_command :sticker, :set, type, uri, name, value
      end

      # Deletes a sticker value from the specified object. If you do
      # not specify a sticker name, all sticker values are deleted.
      def delete_sticker(type, uri, name = nil)
        send_command :sticker, :delete, type, uri, name
      end

      # Lists the stickers for the specified object.
      # @return [Hash] Hash mapping sticker names (as strings) to values (as strings).
      def list_stickers(type, uri)
        result = send_command :sticker, :list, type, uri
        case result
        when true then {}  # response when there are no stickers
        when nil  then nil # when called in a command_list
        else
          result = [result] if result.is_a?(String)
          Hash[result.map{|s| s.split('=',2)}]
        end
      end

      # Searches the sticker database for stickers with the specified name,
      # below the specified directory (URI). For each matching song, it prints
      # the URI and that one sticker's value.
      def find_sticker(type, uri, name)
        send_command :sticker, :find, type, uri, name
      end
    end

  end
end
