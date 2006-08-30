#
# Unit tests for librmpd test server
#
# This tests the MPDTestServer class

#require 'rubygems'
#require 'librmpd'
load '../lib/mpdserver.rb'
require 'test/unit'
require 'socket'

class MPDTester < Test::Unit::TestCase

	def setup
		begin
			@port = 9393
			@mpd = MPDTestServer.new @port, '../lib/database.yaml'
			@mpd.start
			@sock = TCPSocket.new 'localhost', @port
		rescue Errno::EADDRINUSE
			@port = 9494
			@mpd = MPDTestServer.new @port, '../lib/database.yaml'
			@mpd.start
			@sock = TCPSocket.new 'localhost', @port
		end
	end

	def teardown
		@mpd.stop
	end

	def get_response
		msg = ''
		reading = true
		error = nil
		while reading
			line = @sock.gets
			case line
				when "OK\n"
					reading = false;
				when /^ACK/
					error = line
					reading = false;
				else
					msg += line
			end
		end

		if error.nil?
			return msg
		else
			raise error.gsub( /^ACK \[(\d+)\@(\d+)\] \{(.+)\} (.+)$/, 'MPD Error #\1: \3: \4')
		end
  end

	def build_hash( reply )
		lines = reply.split "\n"

		hash = {}
		lines.each do |l|
			key = l.gsub(/^([^:]*): .*/, '\1')
			hash[key.downcase] = l.gsub( key + ': ', '' )
		end

		return hash
	end

	def build_songs( reply )
		lines = reply.split "\n"

		song = nil
		songs = []
		lines.each do |l|
			if l =~ /^file: /
				songs << song unless song == nil
				song = {}
				song['file'] = l.gsub(/^file: /, '')
			else
				key = l.gsub( /^([^:]*): .*/, '\1' )
				song[key] = l.gsub( key + ': ', '' )
			end
		end

		songs << song

		return songs
	end

	def extract_song( lines )
		song = {}
		lines.each do |l|
			key = l.gsub /^([^:]*): .*/, '\1'
			song[key] = l.gsub key + ': ', ''
		end

		return song
	end

	def test_connect
		assert_equal "OK MPD 0.11.5\n", @sock.gets
	end

	def test_add
		@sock.gets

		# Add w/o args (Adds All Songs)
		@sock.puts 'add'
		assert_equal "OK\n", @sock.gets

		@sock.puts 'playlist'
		reply = get_response
		songs = reply.split "\n"
		assert_equal 46, songs.length

		@sock.puts 'clear'
		assert_equal "OK\n", @sock.gets

		# Add a dir
		@sock.puts 'add Shpongle'
		assert_equal "OK\n", @sock.gets

		@sock.puts 'playlist'
		reply = get_response
		songs = reply.split "\n"
		assert_equal 27, songs.length

		@sock.puts 'clear'
		assert_equal "OK\n", @sock.gets

		@sock.puts 'add Shpongle/Are_You_Shpongled'
		assert_equal "OK\n", @sock.gets

		@sock.puts 'playlist'
		reply = get_response
		songs = reply.split "\n"
		assert_equal 7, songs.length

		@sock.puts 'clear'
		assert_equal "OK\n", @sock.gets

		# Add a song
		@sock.puts 'add Shpongle/Are_You_Shpongled/1.Shpongle_Falls.ogg'
		assert_equal "OK\n", @sock.gets

		@sock.puts 'playlist'
		reply = get_response
		songs = reply.split "\n"
		assert_equal 1, songs.length
		assert_equal '0: Shpongle/Are_You_Shpongled/1.Shpongle_Falls.ogg', songs[0]

		# Add a non existant item
		@sock.puts 'add ABOMINATION'
		assert_equal "ACK [50@0] {add} directory or file not found\n", @sock.gets
	end

	def test_clear
		@sock.gets

		@sock.puts 'add'
		assert_equal "OK\n", @sock.gets

		@sock.puts 'playlist'
		reply = get_response
		songs = reply.split "\n"
		assert_equal 46, songs.length

		@sock.puts 'clear'
		assert_equal "OK\n", @sock.gets

		@sock.puts 'playlist'
		assert_equal "OK\n", @sock.gets

		# Test improper args
		@sock.puts 'clear blah'
		assert_equal "ACK [2@0] {clear} wrong number of arguments for \"clear\"\n", @sock.gets
	end

	def test_clearerror
		# TODO
	end

	def test_close
		@sock.gets

		# Test improper args
		@sock.puts 'close blah'
		assert_raises(Errno::EPIPE) { @sock.puts 'data' }

		@sock = TCPSocket.new 'localhost', @port
		@sock.puts 'close'
		assert_raises(Errno::EPIPE) { @sock.puts 'data' }

	end

	def test_crossfade
		@sock.gets

		# Test no args
		@sock.puts 'crossfade'
		assert_equal "ACK [2@0] {crossfade} wrong number of arguments for \"crossfade\"\n", @sock.gets

		# Test not a number arg
		@sock.puts 'crossfade a'
		assert_equal "ACK [2@0] {crossfade} \"a\" is not a integer >= 0\n", @sock.gets

		# Test arg < 0
		@sock.puts 'crossfade -1'
		assert_equal "ACK [2@0] {crossfade} \"-1\" is not a integer >= 0\n", @sock.gets

		# Test correct arg
		@sock.puts 'crossfade 10'
		assert_equal "OK\n", @sock.gets

		@sock.puts 'status'
		hash = build_hash(get_response)
		assert_equal '10', hash['xfade']

		@sock.puts 'crossfade 49'
		assert_equal "OK\n", @sock.gets

		@sock.puts 'status'
		hash = build_hash(get_response)
		assert_equal '49', hash['xfade']
	end

	def test_current_song
		# TODO
	end

	def test_delete
		@sock.gets

		@sock.puts 'add Shpongle/Are_You_Shpongled'
		assert_equal "OK\n", @sock.gets

		@sock.puts 'playlist'
		reply = get_response
		songs = reply.split "\n"
		assert_equal 7, songs.length
		assert_equal '0: Shpongle/Are_You_Shpongled/1.Shpongle_Falls.ogg', songs[0]
		assert_equal '1: Shpongle/Are_You_Shpongled/2.Monster_Hit.ogg', songs[1]

		# Test correct arg
		@sock.puts 'delete 0'
		assert_equal "OK\n", @sock.gets

		@sock.puts 'playlist'
		reply = get_response
		songs = reply.split "\n"
		assert_equal 6, songs.length
		assert_equal '0: Shpongle/Are_You_Shpongled/2.Monster_Hit.ogg', songs[0]
		assert_equal '3: Shpongle/Are_You_Shpongled/5.Behind_Closed_Eyelids.ogg', songs[3]
		assert_equal '4: Shpongle/Are_You_Shpongled/6.Divine_Moments_of_Truth.ogg', songs[4]

		@sock.puts 'delete 3'
		assert_equal "OK\n", @sock.gets

		@sock.puts 'playlist'
		reply = get_response
		songs = reply.split "\n"
		assert_equal 5, songs.length
		assert_equal '0: Shpongle/Are_You_Shpongled/2.Monster_Hit.ogg', songs[0]
		assert_equal '2: Shpongle/Are_You_Shpongled/4.Shpongle_Spores.ogg', songs[2]
		assert_equal '3: Shpongle/Are_You_Shpongled/6.Divine_Moments_of_Truth.ogg', songs[3]
		assert_equal '4: Shpongle/Are_You_Shpongled/7...._and_the_Day_Turned_to_Night.ogg', songs[4]

		# Test arg == length
		@sock.puts 'delete 5'
		assert_equal "ACK [50@0] {delete} song doesn't exist: \"5\"\n", @sock.gets

		# Test arg > length
		@sock.puts 'delete 900'
		assert_equal "ACK [50@0] {delete} song doesn't exist: \"900\"\n", @sock.gets

		# Test arg < 0
		@sock.puts 'delete -1'
		assert_equal "ACK [50@0] {delete} song doesn't exist: \"-1\"\n", @sock.gets

		# Test no args
		@sock.puts 'delete'
		assert_equal "ACK [2@0] {delete} wrong number of arguments for \"delete\"\n", @sock.gets
	end

	def test_deleteid
		@sock.gets

		@sock.puts 'add Shpongle/Are_You_Shpongled'
		assert_equal "OK\n", @sock.gets

		@sock.puts 'playlist'
		reply = get_response
		songs = reply.split "\n"
		assert_equal 7, songs.length
		assert_equal '0: Shpongle/Are_You_Shpongled/1.Shpongle_Falls.ogg', songs[0]
		assert_equal '1: Shpongle/Are_You_Shpongled/2.Monster_Hit.ogg', songs[1]

		# Test correct arg
		@sock.puts 'deleteid 0'
		assert_equal "OK\n", @sock.gets

		@sock.puts 'playlist'
		reply = get_response
		songs = reply.split "\n"
		assert_equal 6, songs.length
		assert_equal '0: Shpongle/Are_You_Shpongled/2.Monster_Hit.ogg', songs[0]
		assert_equal '1: Shpongle/Are_You_Shpongled/3.Vapour_Rumours.ogg', songs[1]
		assert_equal '2: Shpongle/Are_You_Shpongled/4.Shpongle_Spores.ogg', songs[2]

		@sock.puts 'deleteid 3'
		assert_equal "OK\n", @sock.gets

		@sock.puts 'playlist'
		reply = get_response
		songs = reply.split "\n"
		assert_equal 5, songs.length
		assert_equal '0: Shpongle/Are_You_Shpongled/2.Monster_Hit.ogg', songs[0]
		assert_equal '1: Shpongle/Are_You_Shpongled/3.Vapour_Rumours.ogg', songs[1]
		assert_equal '2: Shpongle/Are_You_Shpongled/5.Behind_Closed_Eyelids.ogg', songs[2]

		# Test arg no present but valid
		@sock.puts 'deleteid 8'
		assert_equal "ACK [50@0] {deleteid} song id doesn't exist: \"8\"\n", @sock.gets

		# Test arg > length
		@sock.puts 'deleteid 900'
		assert_equal "ACK [50@0] {deleteid} song id doesn't exist: \"900\"\n", @sock.gets

		# Test arg < 0
		@sock.puts 'deleteid -1'
		assert_equal "ACK [50@0] {deleteid} song id doesn't exist: \"-1\"\n", @sock.gets

		# Test no args
		@sock.puts 'deleteid'
		assert_equal "ACK [2@0] {deleteid} wrong number of arguments for \"deleteid\"\n", @sock.gets
	end

	def test_find
		@sock.gets

		# Test no args
		@sock.puts 'find'
		assert_equal "ACK [2@0] {find} wrong number of arguments for \"find\"\n", @sock.gets

		# Test one arg
		@sock.puts 'find album'
		assert_equal "ACK [2@0] {find} wrong number of arguments for \"find\"\n", @sock.gets

		# Test incorrect args
		@sock.puts 'find wrong test'
		assert_equal "ACK [2@0] {find} incorrect arguments\n", @sock.gets

		# Test album search
		@sock.puts 'find album "Are You Shpongled?"'
		songs = build_songs(get_response)
		assert_equal 7, songs.length
		assert_equal 'Shpongle/Are_You_Shpongled/1.Shpongle_Falls.ogg', songs[0]['file']
		assert_equal 'Shpongle/Are_You_Shpongled/2.Monster_Hit.ogg', songs[1]['file']
		assert_equal 'Shpongle/Are_You_Shpongled/3.Vapour_Rumours.ogg', songs[2]['file']
		assert_equal 'Shpongle/Are_You_Shpongled/4.Shpongle_Spores.ogg', songs[3]['file']
		assert_equal 'Shpongle/Are_You_Shpongled/5.Behind_Closed_Eyelids.ogg', songs[4]['file']
		assert_equal 'Shpongle/Are_You_Shpongled/6.Divine_Moments_of_Truth.ogg', songs[5]['file']
		assert_equal 'Shpongle/Are_You_Shpongled/7...._and_the_Day_Turned_to_Night.ogg', songs[6]['file']

		songs.each_with_index do |s,i|
			assert_equal 'Shpongle', s['Artist']
			assert_equal 'Are You Shpongled?', s['Album']
			assert_equal (i+1).to_s, s['Track']
			assert_not_nil s['Time']
		end

		# Test artist search
		@sock.puts 'find artist "Carbon Based Lifeforms"'
		songs = build_songs(get_response)
		assert_equal 11, songs.length
		assert_equal 'Carbon_Based_Lifeforms/Hydroponic_Garden/01.Central_Plains.ogg', songs[0]['file']
		assert_equal 'Carbon_Based_Lifeforms/Hydroponic_Garden/02.Tensor.ogg', songs[1]['file']
		assert_equal 'Carbon_Based_Lifeforms/Hydroponic_Garden/03.MOS_6581_(Album_Version).ogg', songs[2]['file']
		assert_equal 'Carbon_Based_Lifeforms/Hydroponic_Garden/04.Silent_Running.ogg', songs[3]['file']
		assert_equal 'Carbon_Based_Lifeforms/Hydroponic_Garden/05.Neurotransmitter.ogg', songs[4]['file']
		assert_equal 'Carbon_Based_Lifeforms/Hydroponic_Garden/06.Hydroponic_Garden.ogg', songs[5]['file']
		assert_equal 'Carbon_Based_Lifeforms/Hydroponic_Garden/07.Exosphere.ogg', songs[6]['file']
		assert_equal 'Carbon_Based_Lifeforms/Hydroponic_Garden/08.Comsat.ogg', songs[7]['file']
		assert_equal 'Carbon_Based_Lifeforms/Hydroponic_Garden/09.Epicentre_(First_Movement).ogg', songs[8]['file']
		assert_equal 'Carbon_Based_Lifeforms/Hydroponic_Garden/10.Artificial_Island.ogg', songs[9]['file']
		assert_equal 'Carbon_Based_Lifeforms/Hydroponic_Garden/11.Refraction_1.33.ogg', songs[10]['file']

		songs.each_with_index do |s,i|
			assert_equal 'Carbon Based Lifeforms', s['Artist']
			assert_equal 'Hydroponic Garden', s['Album']
			assert_equal (i+1).to_s, s['Track']
			assert_not_nil s['Time']
		end

		# Test title search
		@sock.puts 'find title "Ambient Galaxy (Disco Valley Mix)"'
		songs = build_songs(get_response)
		assert_equal 1, songs.length
		assert_equal 'Astral_Projection/Dancing_Galaxy/8.Ambient_Galaxy_(Disco_Valley_Mix).ogg', songs[0]['file']
		assert_equal 'Astral Projection', songs[0]['Artist']
		assert_equal 'Dancing Galaxy', songs[0]['Album']
		assert_equal 'Ambient Galaxy (Disco Valley Mix)', songs[0]['Title']
		assert_equal '8', songs[0]['Track']
		assert_equal '825', songs[0]['Time']

	end

	def test_kill
		# TODO
	end

	def test_list
		@sock.gets

		# Test no args
		@sock.puts 'list'
		assert_equal "ACK [2@0] {list} wrong number of arguments for \"list\"\n", @sock.gets

		# Test wrong args
		@sock.puts 'list bad'
		assert_equal "ACK [2@0] {list} \"bad\" is not known\n", @sock.gets

		# Test wrong args
		@sock.puts 'list bad blah'
		assert_equal "ACK [2@0] {list} \"bad\" is not known\n", @sock.gets

		# Test wrong args
		@sock.puts 'list artist blah'
		assert_equal "ACK [2@0] {list} should be \"Album\" for 3 arguments\n", @sock.gets

		# Test album
		@sock.puts 'list album'
		reply = get_response
		albums = reply.split "\n"
		assert_equal 4, albums.length
		assert_equal 'Album: Are You Shpongled?', albums[0]
		assert_equal 'Album: Dancing Galaxy', albums[1]
		assert_equal 'Album: Hydroponic Garden', albums[2]
		assert_equal 'Album: Nothing Lasts... But Nothing Is Lost', albums[3]

		# Test album + artist
		@sock.puts 'list album Shpongle'
		reply = get_response
		albums = reply.split "\n"
		assert_equal 2, albums.length
		assert_equal 'Album: Are You Shpongled?', albums[0]
		assert_equal 'Album: Nothing Lasts... But Nothing Is Lost', albums[1]

		# Test album + non artist
		@sock.puts 'list album zero'
		assert_equal "OK\n", @sock.gets

		# Test artist
		@sock.puts 'list artist'
		reply = get_response
		artists = reply.split "\n"
		assert_equal 3, artists.length
		assert_equal 'Artist: Astral Projection', artists[0]
		assert_equal 'Artist: Carbon Based Lifeforms', artists[1]
		assert_equal 'Artist: Shpongle', artists[2]

		# Test title
		@sock.puts 'list title'
		reply = get_response
		titles = reply.split "\n"
		assert_equal 46, titles.length
		assert_equal 'Title: ... and the Day Turned to Night', titles[0]
		assert_equal 'Title: ...But Nothing Is Lost', titles[1]
		assert_equal 'Title: When Shall I Be Free', titles[45]

	end

	def test_listall
		@sock.gets

		# Test too many args
		@sock.puts 'listall blah blah'
		assert_equal "ACK [2@0] {listall} wrong number of arguments for \"listall\"\n", @sock.gets

		# Test no args
		@sock.puts 'listall'
		reply = get_response
		lines = reply.split "\n"
		assert_equal 53, lines.length
		assert_equal 'directory: Astral_Projection', lines[0]
		assert_equal 'directory: Astral_Projection/Dancing_Galaxy', lines[1]
		assert_equal 'file: Astral_Projection/Dancing_Galaxy/1.Dancing_Galaxy.ogg', lines[2]
		for i in 3...10
			assert lines[i] =~ /^file: Astral_Projection\/Dancing_Galaxy\//
		end

		assert_equal 'directory: Carbon_Based_Lifeforms', lines[10]
		assert_equal 'directory: Carbon_Based_Lifeforms/Hydroponic_Garden', lines[11]
		assert_equal 'file: Carbon_Based_Lifeforms/Hydroponic_Garden/01.Central_Plains.ogg', lines[12]
		for i in 13...23
			assert lines[i] =~ /^file: Carbon_Based_Lifeforms\/Hydroponic_Garden\//
		end

		assert_equal 'directory: Shpongle', lines[23]
		assert_equal 'directory: Shpongle/Are_You_Shpongled', lines[24]
		assert_equal 'file: Shpongle/Are_You_Shpongled/1.Shpongle_Falls.ogg', lines[25]
		for i in 26...32
			assert lines[i] =~ /^file: Shpongle\/Are_You_Shpongled\//
		end

		assert_equal 'directory: Shpongle/Nothing_Lasts..._But_Nothing_Is_Lost', lines[32]
		assert_equal 'file: Shpongle/Nothing_Lasts..._But_Nothing_Is_Lost/01.Botanical_Dimensions.ogg', lines[33]
		for i in 34...53
			assert lines[i] =~ /^file: Shpongle\/Nothing_Lasts..._But_Nothing_Is_Lost\//
		end

		# Test one arg
		@sock.puts 'listall Carbon_Based_Lifeforms'
		reply = get_response
		lines = reply.split "\n"
		assert_equal 13, lines.length
		assert_equal 'directory: Carbon_Based_Lifeforms', lines[0]
		assert_equal 'directory: Carbon_Based_Lifeforms/Hydroponic_Garden', lines[1]
		assert_equal 'file: Carbon_Based_Lifeforms/Hydroponic_Garden/01.Central_Plains.ogg', lines[2]
		for i in 2...13
			assert lines[i] =~ /^file: Carbon_Based_Lifeforms\/Hydroponic_Garden\//
		end

		@sock.puts 'listall Shpongle/Are_You_Shpongled'
		reply = get_response
		lines = reply.split "\n"
		assert_equal 8, lines.length
		assert_equal 'directory: Shpongle/Are_You_Shpongled', lines[0]
		assert_equal 'file: Shpongle/Are_You_Shpongled/1.Shpongle_Falls.ogg', lines[1]
		for i in 2...8
			assert lines[i] =~ /^file: Shpongle\/Are_You_Shpongled\//
		end

		@sock.puts 'listall nothere'
		assert_equal "ACK [50@0] {listall} directory or file not found\n", @sock.gets

		@sock.puts 'listall Shpongle/nothere'
		assert_equal "ACK [50@0] {listall} directory or file not found\n", @sock.gets

	end

	def test_listallinfo
		@sock.gets

		# Test too many args
		@sock.puts 'listallinfo blah blah'
		assert_equal "ACK [2@0] {listallinfo} wrong number of arguments for \"listallinfo\"\n", @sock.gets

		# Test no args
		@sock.puts 'listallinfo'
		reply = get_response
		lines = reply.split "\n"
		assert_equal 329, lines.length
		assert_equal 'directory: Astral_Projection', lines[0]
		assert_equal 'directory: Astral_Projection/Dancing_Galaxy', lines[1]
		assert_equal 'file: Astral_Projection/Dancing_Galaxy/1.Dancing_Galaxy.ogg', lines[2]
		song = extract_song lines[3..8]
		assert_equal 'Astral Projection', song['Artist']
		assert_equal 'Dancing Galaxy', song['Album']
		assert_equal 'Dancing Galaxy', song['Title']
		assert_equal '558', song['Time']
		assert_equal '1', song['Track']
		assert_equal '7', song['Id']

		song_num = 1
		while song_num < 8
			index = (song_num * 7) + 2
			song = extract_song lines[index..(index+6)]
			assert_equal 'Astral Projection', song['Artist']
			assert_equal 'Dancing Galaxy', song['Album']
			assert_equal (song_num+1).to_s, song['Track']
			assert_equal (song_num+7).to_s, song['Id']
			assert_not_nil song['Time']
			assert_not_nil song['Title']
			assert_not_nil song['file']
			song_num += 1
		end

		assert_equal 'directory: Carbon_Based_Lifeforms', lines[58]
		assert_equal 'directory: Carbon_Based_Lifeforms/Hydroponic_Garden', lines[59]
		assert_equal 'file: Carbon_Based_Lifeforms/Hydroponic_Garden/01.Central_Plains.ogg', lines[60]

		song = extract_song lines[61..66]
		assert_equal 'Carbon Based Lifeforms', song['Artist']
		assert_equal 'Hydroponic Garden', song['Album']
		assert_equal 'Central Plains', song['Title']
		assert_equal '1', song['Track']
		assert_equal '15', song['Id']

		song_num = 1
		while song_num < 11
			index = (song_num * 7) + 60
			song = extract_song lines[index..(index+6)]
			assert_equal 'Carbon Based Lifeforms', song['Artist']
			assert_equal 'Hydroponic Garden', song['Album']
			assert_equal (song_num+1).to_s, song['Track']
			assert_equal (song_num+15).to_s, song['Id']
			assert_not_nil song['Time']
			assert_not_nil song['Title']
			assert_not_nil song['file']
			song_num += 1
		end

		assert_equal 'directory: Shpongle', lines[137]
		assert_equal 'directory: Shpongle/Are_You_Shpongled', lines[138]
		assert_equal 'file: Shpongle/Are_You_Shpongled/1.Shpongle_Falls.ogg', lines[139]

		song = extract_song lines[140..145]
		assert_equal 'Shpongle', song['Artist']
		assert_equal 'Are You Shpongled?', song['Album']
		assert_equal 'Shpongle Falls', song['Title']
		assert_equal '1', song['Track']
		assert_equal '0', song['Id']

		song_num = 1
		while song_num < 7
			index = (song_num * 7) + 139
			song = extract_song lines[index..(index+6)]
			assert_equal 'Shpongle', song['Artist']
			assert_equal 'Are You Shpongled?', song['Album']
			assert_equal (song_num+1).to_s, song['Track']
			assert_equal (song_num).to_s, song['Id']
			assert_not_nil song['Time']
			assert_not_nil song['Title']
			assert_not_nil song['file']
			song_num += 1
		end

		assert_equal 'directory: Shpongle/Nothing_Lasts..._But_Nothing_Is_Lost', lines[188]
		assert_equal 'file: Shpongle/Nothing_Lasts..._But_Nothing_Is_Lost/01.Botanical_Dimensions.ogg', lines[189]

		song = extract_song lines[190..195]
		assert_equal 'Shpongle', song['Artist']
		assert_equal 'Nothing Lasts... But Nothing Is Lost', song['Album']
		assert_equal 'Botanical Dimensions', song['Title']
		assert_equal '1', song['Track']
		assert_equal '26', song['Id']

		song_num = 1
		while song_num < 20
			index = (song_num * 7) + 189
			song = extract_song lines[index..(index+6)]
			assert_equal 'Shpongle', song['Artist']
			assert_equal 'Nothing Lasts... But Nothing Is Lost', song['Album']
			assert_equal (song_num+1).to_s, song['Track']
			assert_equal (song_num+26).to_s, song['Id']
			assert_not_nil song['Time']
			assert_not_nil song['Title']
			assert_not_nil song['file']
			song_num += 1
		end

		# Test one arg that doesn't exist
		@sock.puts 'listallinfo noentry'
		assert_equal "ACK [50@0] {listallinfo} directory or file not found\n", @sock.gets

		# Test one arg that exists
		@sock.puts 'listallinfo Carbon_Based_Lifeforms'
		reply = get_response
		lines = reply.split "\n"
		assert_equal 'directory: Carbon_Based_Lifeforms', lines[0]
		assert_equal 'directory: Carbon_Based_Lifeforms/Hydroponic_Garden', lines[1]
		lines.shift
		lines.shift
		reply = lines.join "\n"
		songs = build_songs reply
		
		songs.each_with_index do |s,i|
			assert_equal 'Carbon Based Lifeforms', s['Artist']
			assert_equal 'Hydroponic Garden', s['Album']
			assert_equal (i+1).to_s, s['Track']
			assert_equal (i+15).to_s, s['Id']
			assert_not_nil s['Time']
			assert_nil s['directory']
		end
	end
end
