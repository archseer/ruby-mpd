require '../lib/ruby-mpd'
require './socket_spoof'

class RecordingMPD < MPD
	def socket
		@recording_socket ||= SocketSpoof::Recorder.new(super)
	end
end

m = RecordingMPD.new('music.local').tap(&:connect)
begin
	s = ["gavin/Basic Pleasure Model/How to Live/01 How to Live (Album Version).m4a","gavin/Basic Pleasure Model/Sunyata/01 Sunyata (album Version).m4a"]
	m.command_list{ s.each{ |f| addid(f) } }
	m.queue
	m.playlists.find{ |pl| pl.name=='user-gkistner' }.songs
end