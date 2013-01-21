class MPD
  module Plugins
    # Informational commands regarding MPD's internals and config.
    module Reflection
      # Returns the config of MPD (currently only music_directory).
      # Only works if connected trough an UNIX domain socket.
      # @return [Hash] Configuration of MPD
      def config
        send_command :config
      end

      # Shows which commands the current user has access to.
      # @return [Array<Symbol>] Array of command names.
      def commands
        send_command :commands
      end

      # Shows which commands the current user does not have access to.
      # @return [Array<Symbol>] Array of command names.
      def notcommands
        send_command :notcommands
      end

      # Gets a list of available URL handlers.
      # @return [Array<String>] Array of URL's MPD can handle.
      def url_handlers
        send_command :urlhandlers
      end

      # Get a list of decoder plugins, with by their supported suffixes
      # and MIME types.
      # @return [Array<Hash>] An array of hashes, one per decoder.
      def decoders
        send_command :decoders
      end

      # Get a list of available song metadata fields. This gets only
      # mapped once per-connect (it gets remapped if you connect and
      # disconnect).
      # @return [Array] An array of tags.
      def tags
        @tags ||= send_command(:tagtypes).map {|tag| tag.downcase }
      end
    end
  end
end