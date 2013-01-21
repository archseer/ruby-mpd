class MPD
  # Standard MPD error.
  class Error < StandardError; end
  # When something goes wrong with the connection
  class ConnectionError < Error; end
  # When the server returns an error
  class ServerError < Error
    def initialize string
      @error = string.match(/^ACK \[(?<code>\d+)\@(?<pos>\d+)\] \{(?<command>.*)\} (?<message>.+)$/)
      super("#{@error[:code]}: #{@error[:command]}: #{@error[:message]}")
    end
  end
end