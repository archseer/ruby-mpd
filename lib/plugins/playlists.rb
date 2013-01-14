class MPD
  module Plugins
    # These commands manipulate stored playlists.
    #
    # Changes: listplaylists -> playlists.
    module Playlists

      # List all of the playlists in the database
      # 
      # @return [Array<Hash>] Array of playlists
      def playlists
        send_command(:listplaylists).map {|opt| MPD::Playlist.new(self, opt)}
      end

      # Saves the current playlist/queue to `playlist`.m3u in the
      # playlist directory.
      # @macro returnraise
      def save(playlist)
        send_command :save, playlist
      end

    end
  end
end