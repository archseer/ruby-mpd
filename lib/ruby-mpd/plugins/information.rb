class MPD
  module Plugins
    # Informational commands regarding MPD's current status.
    module Information

      # Clears the current error message reported in status
      # (also accomplished by any command that starts playback).
      #
      # @macro returnraise
      def clearerror
        send_command :clearerror
      end

      # Get the currently playing song
      #
      # @return [MPD::Song]
      # @return [nil] if there is no song playing
      def current_song
        hash = send_command :currentsong
        # if there is no current song (we get true, then return nil)
        hash.is_a?(TrueClass) ? nil : Song.new(self, hash)
      end

      # Waits until there is a noteworthy change in one or more of MPD's subsystems.
      # As soon as there is one, it lists all changed systems in a line in the format
      # 'changed: SUBSYSTEM', where SUBSYSTEM is one of the following:
      #
      # * *database*: the song database has been modified after update.
      # * *update*: a database update has started or finished. If the database was modified
      #   during the update, the database event is also emitted.
      # * *stored_playlist*: a stored playlist has been modified, renamed, created or deleted
      # * *playlist*: the current playlist has been modified
      # * *player*: the player has been started, stopped or seeked
      # * *mixer*: the volume has been changed
      # * *output*: an audio output has been enabled or disabled
      # * *options*: options like repeat, random, crossfade, replay gain
      # * *sticker*: the sticker database has been modified.
      # * *subscription*: a client has subscribed or unsubscribed to a channel
      # * *message*: a message was received on a channel this client is subscribed to; this
      #   event is only emitted when the queue is empty
      #
      # If the optional +masks+ argument is used, MPD will only send notifications
      # when something changed in one of the specified subsytems.
      #
      # @since MPD 0.14
      # @param [Symbol] masks A list of subsystems we want to be notified on.
      def idle(*masks)
        send_command(:idle, *masks)
      end

      # MPD status: volume, time, modes...
      # * *volume*: 0-100
      # * *repeat*: true or false
      # * *random*: true or false
      # * *single*: true or false
      # * *consume*: true or false
      # * *playlist*: 31-bit unsigned integer, the playlist version number
      # * *playlistlength*: integer, the length of the playlist
      # * *state*: :play, :stop, or :pause
      # * *song*: playlist song number of the current song stopped on or playing
      # * *songid*: playlist songid of the current song stopped on or playing
      # * *nextsong*: playlist song number of the next song to be played
      # * *nextsongid*: playlist songid of the next song to be played
      # * *time*: total time elapsed (of current playing/paused song)
      # * *elapsed*: Total time elapsed within the current song, but with higher resolution.
      # * *bitrate*: instantaneous bitrate in kbps
      # * *xfade*: crossfade in seconds
      # * *mixrampdb*: mixramp threshold in dB
      # * *mixrampdelay*: mixrampdelay in seconds
      # * *audio*: [sampleRate, bits, channels]
      # * *updating_db*: job id
      # * *error*: if there is an error, returns message here
      #
      # @return [Hash] Current MPD status.
      def status
        send_command :status
      end

      # Statistics.
      #
      # * *artists*: number of artists
      # * *songs*: number of albums
      # * *uptime*: daemon uptime in seconds
      # * *db_playtime*: sum of all song times in the db
      # * *db_update*: last db update in a Time object
      # * *playtime*: time length of music played
      #
      # @return [Hash] MPD statistics.
      def stats
        send_command :stats
      end

      # Unofficial additions below

      # Is MPD paused?
      # @return [Boolean]
      def paused?
        status[:state] == :pause
      end

      # Is MPD playing?
      # @return [Boolean]
      def playing?
        status[:state] == :play
      end

      # @return [Boolean] Is MPD stopped?
      def stopped?
        status[:state] == :stop
      end

      # Gets the volume level.
      # @return [Integer]
      def volume
        status[:volume]
      end

      # @return [Integer] Crossfade in seconds.
      def crossfade
        status[:xfade]
      end

      # @return [Integer] Current playlist version number.
      def playlist_version
        status[:playlist]
      end

      # Returns true if consume is enabled.
      def consume?
        status[:consume]
      end

      # Returns true if single is enabled.
      def single?
        status[:single]
      end

      # Returns true if random playback is currently enabled,
      def random?
        status[:random]
      end

      # Returns true if repeat is enabled,
      def repeat?
        status[:repeat]
      end
    end
  end
end
