class MPD
  module Plugins
    # These commands manipulate stored playlists.
    module Playlists

      # List all of the playlists in the database
      #
      # @return [Array<Hash>] Array of playlists
      def playlists
        send_command(:listplaylists).map {|opt| MPD::Playlist.new(self, opt)}
      end

    end
  end
end