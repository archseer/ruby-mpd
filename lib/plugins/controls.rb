class MPD
  module Plugins
    # Commands for controlling playback. Changes have been made to {#seek},
    # command maps to +seekcur+ from MPD and the original seek command is
    # {#seekpos} here.
    module Controls
      # Plays the next song in the playlist.
      # @macro returnraise
      def next
        send_command :next
      end

      # Resume/pause playback.
      # @note The use of pause without an argument is deprecated in MPD.
      # @macro returnraise
      def pause=(toggle)
        send_command :pause, toggle
      end

      # Begin playing the playist.
      # @param [Integer] pos Position in the playlist to start playing.
      # @macro returnraise
      def play(pos = nil)
        send_command :play, pos
      end

      # Begin playing the playlist.
      # @param [Integer] songid ID of the song where to start playing.
      # @macro returnraise
      def playid(songid = nil)
        send_command :playid, songid
      end

      # Plays the previous song in the playlist.
      # @macro returnraise
      def previous
        send_command :previous
      end

      # Seeks to the position in seconds within the current song.
      # If prefixed by '+' or '-', then the time is relative to the current
      # playing position.
      #
      # @since MPD 0.17
      # @param [Integer, String] time Position within the current song.
      # Returns true if successful,
      def seek(time)
        send_command :seekcur, time
      end

      # Seeks to the position +time+ (in seconds) of the
      # song at +pos+ in the playlist.
      # @macro returnraise
      def seekpos(pos, time)
        send_command :seek, pos, time
      end

      # Seeks to the position +time+ (in seconds) of the song with
      # the id of +songid+.
      # @macro returnraise
      def seekid(songid, time)
        send_command :seekid, songid, time
      end

      # Stop playing.
      # @macro returnraise
      def stop
        send_command :stop
      end
    end
  end
end