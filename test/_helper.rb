require_relative '../lib/ruby-mpd'
require_relative './socket_spoof'
require 'minitest/autorun'

class PlaybackMPD < MPD
  def initialize( recordings_directory=nil )
    super()
    @socket = SocketSpoof::Player.new(directory:recordings_directory)
  end
  def last_messages
    @socket.last_messages
  end
end
