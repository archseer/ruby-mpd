require '../lib/ruby-mpd'
require './socket_spoof'

class RecordingMPD < MPD
	def socket
		@recording_socket ||= SocketSpoof::Recorder.new(super)
	end
end

m = RecordingMPD.new.tap(&:connect)
begin
	m.command_list{ s.each{ |f| addid(f) } }
end