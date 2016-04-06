class MPD
  module Plugins
    # These commands manipulate stored playlists.
    module Playlists

      # List all of the playlists in the database
      #
      # @return [Array<MPD::Playlist>] Array of playlists
      def playlists
        send_command(:listplaylists)
      end

    end
  end
end
