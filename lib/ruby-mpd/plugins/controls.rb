class MPD
  module Plugins
    # Commands for controlling playback.
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

      # Begin/resume playing the queue.
      # @param [Integer] pos Position in the playlist to start playing.
      # @param [Hash] pos :id of the song where to start playing.
      # @macro returnraise
      def play(pos = nil)
        if pos.is_a?(Hash) 
          if pos[:id]
            send_command :playid, priority, pos[:id]
          else
            raise ArgumentError, 'Only :id key is allowed!'
          end
        else
          send_command :play, pos
        end
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
      # @param [Hash] options Either +:id+ or +:pos+ can be specified.
      # @macro returnraise
      def seek(time, options = {})
        if options[:id]
          send_command :seekid, options[:id], time
        elsif options[:pos]
          send_command :seek, options[:pos], time
        else
          send_command :seekcur, time
        end
      end

      # Stop playing.
      # @macro returnraise
      def stop
        send_command :stop
      end
    end
  end
end