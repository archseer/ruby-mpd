class MPD
  module Plugins
    # Commands related to setting various aspects and modes of playback.
    #
    # Changes: setvol -> volume.
    module PlaybackOptions

      # Enable/disable consume mode.
      # @since MPD 0.16
      # When consume is activated, each song played is removed from playlist
      # after playing.
      # @macro returnraise
      def consume=(toggle)
        send_command :consume, toggle
      end

      # Set the crossfade between songs in seconds.
      # @macro returnraise
      def crossfade=(seconds)
        send_command :crossfade, seconds
      end

      # Sets the threshold at which songs will be overlapped. Like crossfading
      # but doesn't fade the track volume, just overlaps. The songs need to have
      # MixRamp tags added by an external tool. 0dB is the normalized maximum
      # volume so use negative values, I prefer -17dB. In the absence of mixramp
      # tags crossfading will be used. See http://sourceforge.net/projects/mixramp
      # @param [Float] decibels Maximum volume level in decibels.
      def mixrampdb=(decibels)
        send_command :mixrampdb, decibels
      end

      # Additional time subtracted from the overlap calculated by mixrampdb.
      # A value of "nan" or Float::NAN disables MixRamp overlapping and falls
      # back to crossfading.
      def mixrampdelay=(seconds)
        send_command :mixrampdelay, seconds
      end

      # Enable/disable random playback.
      # @macro returnraise
      def random=(toggle)
        send_command :random, toggle
      end

      # Enable/disable repeat mode.
      # @macro returnraise
      def repeat=(toggle)
        send_command :repeat, toggle
      end

      # Sets the volume level. (Maps to MPD's +setvol+)
      # @param [Integer] vol Volume level between 0 and 100.
      # @macro returnraise
      def volume=(vol)
        send_command :setvol, vol
      end

      # Enable/disable single mode.
      # @since MPD 0.15
      # When single is activated, playback is stopped after current song,
      # or song is repeated if the 'repeat' mode is enabled.
      # @macro returnraise
      def single=(toggle)
        send_command :single, toggle
      end

      # Sets the replay gain mode. One of :off, :track, :album, :auto.
      # @since MPD 0.16
      # Changing the mode during playback may take several seconds, because
      # the new settings does not affect the buffered data.
      #
      # This command triggers the options idle event.
      # @macro returnraise
      def replay_gain_mode=(mode)
        send_command :replay_gain_mode, mode
      end

      # Prints replay gain options. Currently, only the variable
      # +:replay_gain_mode+ is returned.
      # @since MPD 0.16
      def replay_gain_status
        send_command :replay_gain_status
      end

    end
  end
end