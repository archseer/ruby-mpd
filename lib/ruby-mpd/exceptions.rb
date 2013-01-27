class MPD
  # Standard MPD error.
  class Error < StandardError; end
  # When something goes wrong with the connection
  class ConnectionError < Error; end

  # When the server returns an error. Superclass. Used for ACK_ERROR_UNKNOWN too.
  class ServerError < Error;  end

  class NotListError < ServerError; end # ACK_ERROR_NOT_LIST <-- unused?
  # ACK_ERROR_ARG - There was an error with one of the arguments.
  class ServerArgumentError < ServerError; end
  # MPD server password incorrect - ACK_ERROR_PASSWORD
  class IncorrectPassword < ServerError; end
  # ACK_ERROR_PERMISSION - not permitted to use the command.
  # (Mostly, the solution is to connect via UNIX domain socket)
  class PermissionError < ServerError; end

  # ACK_ERROR_NO_EXIST - The requested resource was not found
  class NotFound < ServerError; end
  # ACK_ERROR_PLAYLIST_MAX - Playlist is at the max size
  class PlaylistMaxError < ServerError; end
  # ACK_ERROR_SYSTEM - One of the systems has errored.
  class SystemError < ServerError; end
  # ACK_ERROR_PLAYLIST_LOAD - unused?
  class PlaylistLoadError < ServerError; end
  # ACK_ERROR_UPDATE_ALREADY - Already updating the DB.
  class AlreadyUpdating < ServerError; end
  # ACK_ERROR_PLAYER_SYNC - not playing.
  class NotPlaying < ServerError; end
  # ACK_ERROR_EXIST - the resource already exists.
  class AlreadyExists < ServerError; end
end
