#
# Unit tests for librmpd
#
# This uses the included mpdserver.rb test server

require 'rubygems'
#require 'librmpd'
load '../lib/librmpd.rb'
load '../lib/mpdserver.rb'
require 'test/unit'

class MPDTester < Test::Unit::TestCase

	def setup
		begin
			@port = 9393
			@server = MPDTestServer.new @port, '../lib/database.yaml'
			@server.start
		rescue Errno::EADDRINUSE
			@port = 9494
			@server = MPDTestServer.new @port, '../lib/database.yaml'
			@server.start
		end
		@mpd = MPD.new 'localhost', @port
	end

	def teardown
		@mpd.disconnect
		@server.stop
	end

	def test_connect
		ret = @mpd.connect
		assert_match /OK MPD [0-9.]*\n/, ret
	end

	def test_connected?
		# test a good connection
		@mpd.connect
		assert @mpd.connected?

		# Test a disconnect
		@server.stop
		assert !@mpd.connected?

		# test a bad connection
		bad = MPD.new 'no-connection', 6600
		assert !bad.connected?
	end

	def test_disconnect
		# test a good connection
		@mpd.connect
		assert @mpd.connected?
		@mpd.disconnect
		assert !@mpd.connected?
		@mpd.disconnect
		assert !@mpd.connected?

		# test a bad connection
		bad = MPD.new 'no-connection'
		bad.disconnect
		assert !bad.connected?
	end

	def test_add
		@mpd.connect
		assert @mpd.connected?

		assert @mpd.add('Shpongle/Are_You_Shpongled/1.Shpongle_Falls.ogg')

		pls = @mpd.playlist
		assert_equal 1, pls.size
		assert_equal 'Shpongle', pls[0].artist
		assert_equal 'Are You Shpongled?', pls[0].album
		assert_equal 'Shpongle Falls', pls[0].title

		assert_raise(RuntimeError) {@mpd.add('Does/Not/Exist')}

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.add('Shpongle')}
	end

	def test_clear
		@mpd.connect
		assert @mpd.connected?

		assert @mpd.add('Shpongle')

		pls = @mpd.playlist
		assert_equal 27, pls.size

		assert @mpd.clear

		pls = @mpd.playlist
		assert_equal 0, pls.size

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.clear}
	end

	def test_clearerror
		@mpd.connect
		assert @mpd.connected?

		assert @mpd.clearerror

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.clearerror}
	end

	def test_crossfade
		@mpd.connect

		@mpd.crossfade = 40

		assert_equal 40, @mpd.crossfade
		assert_equal '40', @mpd.status['xfade']

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.crossfade = 20}
		assert_raise(RuntimeError) {@mpd.crossfade}
	end

	def test_current_song
		@mpd.connect

		s = @mpd.current_song
		assert_nil s

		assert @mpd.add('Shpongle/Are_You_Shpongled/1.Shpongle_Falls.ogg')

		assert @mpd.play

		sleep 2

		assert @mpd.playing?

		s = @mpd.current_song

		assert_equal 'Shpongle', s.artist
		assert_equal 'Are You Shpongled?', s.album
		assert_equal 'Shpongle Falls', s.title
		assert_equal '1', s.track

		@mpd.stop

		sleep 2

		assert !@mpd.playing?

		s = @mpd.current_song

		assert_equal 'Shpongle', s.artist
		assert_equal 'Are You Shpongled?', s.album
		assert_equal 'Shpongle Falls', s.title
		assert_equal '1', s.track

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.current_song}
	end

	def test_delete
		@mpd.connect

		assert @mpd.load('Astral_Projection_-_Dancing_Galaxy')

		assert @mpd.delete(3)

		pls = @mpd.playlist
		assert_equal 7, pls.size
		pls.each do |song|
			assert_not_equal 'No On Ever Dreams', song.title
		end

		assert_raise(RuntimeError) {@mpd.delete(999)}

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.delete(3)}
	end

	def test_deleteid
		@mpd.connect

		assert @mpd.load('Astral_Projection_-_Dancing_Galaxy')

		assert @mpd.deleteid(10)

		pls = @mpd.playlist
		assert_equal 7, pls.size
		pls.each do |song|
			assert_not_equal 'No One Ever Dreams', song.title
		end

		assert_raise(RuntimeError) {@mpd.deleteid(999)}

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.deleteid(11)}
	end

	def test_find
		@mpd.connect

		a = @mpd.find 'album', 'Are You Shpongled?'
		assert_equal 7, a.size
		assert_equal 'Shpongle Falls', a[0].title
		assert_equal 'Monster Hit', a[1].title
		assert_equal 'Vapour Rumours', a[2].title
		assert_equal 'Shpongle Spores', a[3].title
		assert_equal 'Behind Closed Eyelids', a[4].title
		assert_equal 'Divine Moments of Truth', a[5].title
		assert_equal '... and the Day Turned to Night', a[6].title

		b = @mpd.find 'artist', 'Carbon Based Lifeforms'
		assert_equal 11, b.size
		assert_equal 'Central Plains', b[0].title
		assert_equal 'Tensor', b[1].title
		assert_equal 'MOS 6581 (Album Version)', b[2].title
		assert_equal 'Silent Running', b[3].title
		assert_equal 'Neurotransmitter', b[4].title
		assert_equal 'Hydroponic Garden', b[5].title
		assert_equal 'Exosphere', b[6].title
		assert_equal 'Comsat', b[7].title
		assert_equal 'Epicentre (First Movement)', b[8].title
		assert_equal 'Artificial Island', b[9].title
		assert_equal 'Refraction 1.33', b[10].title

		c = @mpd.find 'title', 'Silent Running'
		assert_equal 1, c.size
		assert_equal 'Silent Running', c[0].title

		d = @mpd.find 'artist', 'no artist'
		assert_equal 0, d.size

		assert_raise(RuntimeError) {@mpd.find('error', 'no-such')}

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.find('album', 'Are You Shpongled')}
	end

	def test_kill
		@mpd.connect

		assert @mpd.kill

		assert !@mpd.connected?

		assert_raise(RuntimeError) {@mpd.kill}
	end

	def test_albums
		@mpd.connect

		albums = @mpd.albums

		assert_equal 4, albums.size
		assert_equal 'Are You Shpongled?', albums[0]
		assert_equal 'Dancing Galaxy', albums[1]
		assert_equal 'Hydroponic Garden', albums[2]
		assert_equal 'Nothing Lasts... But Nothing Is Lost', albums[3]

		sh = @mpd.albums 'Shpongle'

		assert_equal 2, sh.size
		assert_equal 'Are You Shpongled?', sh[0]
		assert_equal 'Nothing Lasts... But Nothing Is Lost', sh[1]

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.albums}
	end

	def test_artists
		@mpd.connect

		artists = @mpd.artists

		assert_equal 3, artists.size
		assert_equal 'Astral Projection', artists[0]
		assert_equal 'Carbon Based Lifeforms', artists[1]
		assert_equal 'Shpongle', artists[2]

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.artists}
	end

	def test_list
		@mpd.connect

		albums = @mpd.list 'album'

		assert_equal 4, albums.size
		assert_equal 'Are You Shpongled?', albums[0]
		assert_equal 'Dancing Galaxy', albums[1]
		assert_equal 'Hydroponic Garden', albums[2]
		assert_equal 'Nothing Lasts... But Nothing Is Lost', albums[3]

		artists = @mpd.list 'artist'

		assert_equal 3, artists.size
		assert_equal 'Astral Projection', artists[0]
		assert_equal 'Carbon Based Lifeforms', artists[1]
		assert_equal 'Shpongle', artists[2]

		arg = @mpd.list 'album', 'Shpongle'

		assert_equal 2, arg.size
		assert_equal 'Are You Shpongled?', arg[0]
		assert_equal 'Nothing Lasts... But Nothing Is Lost', arg[1]

		assert_raise(RuntimeError) {@mpd.list('fail')}
		assert_raise(RuntimeError) {@mpd.list('fail', 'Shpongle')}

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.artists}
	end

	def test_directories
		@mpd.connect

		dirs = @mpd.directories
		
		assert_equal 7, dirs.size
		assert_equal 'Astral_Projection', dirs[0]
		assert_equal 'Astral_Projection/Dancing_Galaxy', dirs[1]
		assert_equal 'Carbon_Based_Lifeforms', dirs[2]
		assert_equal 'Carbon_Based_Lifeforms/Hydroponic_Garden', dirs[3]
		assert_equal 'Shpongle', dirs[4]
		assert_equal 'Shpongle/Are_You_Shpongled', dirs[5]
		assert_equal 'Shpongle/Nothing_Lasts..._But_Nothing_Is_Lost', dirs[6]

		shpongle = @mpd.directories 'Shpongle'

		assert_equal 3, shpongle.size
		assert_equal 'Shpongle', shpongle[0]
		assert_equal 'Shpongle/Are_You_Shpongled', shpongle[1]
		assert_equal 'Shpongle/Nothing_Lasts..._But_Nothing_Is_Lost', shpongle[2]

		assert_raise(RuntimeError) {@mpd.directories('no-dirs')}

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.directories}
	end

	def test_files
		@mpd.connect

		files = @mpd.files

		assert_equal 46, files.size

		assert_equal 'Astral_Projection/Dancing_Galaxy/1.Dancing_Galaxy.ogg', files[0]
		assert_equal 'Astral_Projection/Dancing_Galaxy/8.Ambient_Galaxy_(Disco_Valley_Mix).ogg', files[7]
		assert_equal 'Carbon_Based_Lifeforms/Hydroponic_Garden/01.Central_Plains.ogg', files[8]
		assert_equal 'Carbon_Based_Lifeforms/Hydroponic_Garden/11.Refraction_1.33.ogg', files[18]
		assert_equal 'Shpongle/Are_You_Shpongled/1.Shpongle_Falls.ogg', files[19]
		assert_equal 'Shpongle/Are_You_Shpongled/7...._and_the_Day_Turned_to_Night.ogg', files[25]
		assert_equal 'Shpongle/Nothing_Lasts..._But_Nothing_Is_Lost/01.Botanical_Dimensions.ogg', files[26]
		assert_equal 'Shpongle/Nothing_Lasts..._But_Nothing_Is_Lost/20.Falling_Awake.ogg', files[45]

		sh = @mpd.files 'Shpongle'

		assert_equal 27, sh.size

		assert_equal 'Shpongle/Are_You_Shpongled/1.Shpongle_Falls.ogg', sh[0]
		assert_equal 'Shpongle/Are_You_Shpongled/7...._and_the_Day_Turned_to_Night.ogg', sh[6]
		assert_equal 'Shpongle/Nothing_Lasts..._But_Nothing_Is_Lost/01.Botanical_Dimensions.ogg', sh[7]
		assert_equal 'Shpongle/Nothing_Lasts..._But_Nothing_Is_Lost/20.Falling_Awake.ogg', sh[26]

		assert_raise(RuntimeError) {@mpd.files('no-files')}

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.files}
	end

	def test_playlists
		@mpd.connect

		pls = @mpd.playlists

		assert_equal 2, pls.size

		assert_equal 'Shpongle_-_Are_You_Shpongled', pls[0]
		assert_equal 'Astral_Projection_-_Dancing_Galaxy', pls[1]

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.playlists}
	end

	def test_songs
		@mpd.connect

		songs = @mpd.songs

		assert_equal 46, songs.size

		assert_equal 'Dancing Galaxy', songs[0].title
		assert_equal 'Ambient Galaxy (Disco Valley Mix)', songs[7].title
		assert_equal 'Central Plains', songs[8].title
		assert_equal 'Refraction 1.33', songs[18].title
		assert_equal 'Shpongle Falls', songs[19].title
		assert_equal '... and the Day Turned to Night', songs[25].title
		assert_equal 'Botanical Dimensions', songs[26].title
		assert_equal 'Falling Awake', songs[45].title

		sh = @mpd.songs 'Shpongle'

		assert_equal 27, sh.size

		sh.each do |s|
			assert_equal 'Shpongle', s.artist
		end

		assert_equal 'Shpongle Falls', sh[0].title
		assert_equal '... and the Day Turned to Night', sh[6].title
		assert_equal 'Botanical Dimensions', sh[7].title
		assert_equal 'Falling Awake', sh[26].title

		assert_raise(RuntimeError) {@mpd.songs('no-songs')}

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.songs}
	end

	def test_songs_by_artist
		@mpd.connect

		songs = @mpd.songs_by_artist 'Shpongle'

		assert_equal 27, songs.size

		songs.each do |s|
			assert_equal 'Shpongle', s.artist
		end

		assert_equal 'Shpongle Falls', songs[0].title
		assert_equal '... and the Day Turned to Night', songs[6].title
		assert_equal 'Botanical Dimensions', songs[7].title
		assert_equal 'Falling Awake', songs[26].title

		songs = @mpd.songs_by_artist 'no-songs'
		assert_equal 0, songs.size

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.songs_by_artist('Shpongle')}
	end

	def test_load
		@mpd.connect

		assert @mpd.load('Astral_Projection_-_Dancing_Galaxy')

		pls = @mpd.playlist

		assert_equal 8, pls.size
		
		pls.each do |song|
			assert_equal 'Astral Projection', song.artist
			assert_equal 'Dancing Galaxy', song.album
		end

		assert_equal 'Dancing Galaxy', pls[0].title
		assert_equal 'Soundform', pls[1].title
		assert_equal 'Flying Into A Star', pls[2].title
		assert_equal 'No One Ever Dreams', pls[3].title
		assert_equal 'Cosmic Ascension (ft. DJ Jorg)', pls[4].title
		assert_equal 'Life On Mars', pls[5].title
		assert_equal 'Liquid Sun', pls[6].title
		assert_equal 'Ambient Galaxy (Disco Valley Mix)', pls[7].title

		assert_raise(RuntimeError) {@mpd.load('No-PLS')}

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.load('Astral_Projection_-_Dancing_Galaxy')}
	end

	def test_move
		@mpd.connect

		assert @mpd.load('Astral_Projection_-_Dancing_Galaxy')

		assert @mpd.move( 3, 1 )

		pls = @mpd.playlist

		assert_equal 'Dancing Galaxy', pls[0].title
		assert_equal 'No One Ever Dreams', pls[1].title
		assert_equal 'Soundform', pls[2].title
		assert_equal 'Flying Into A Star', pls[3].title

		assert @mpd.move( 2, 7 )

		pls = @mpd.playlist

		assert_equal 'No One Ever Dreams', pls[1].title
		assert_equal 'Flying Into A Star', pls[2].title
		assert_equal 'Cosmic Ascension (ft. DJ Jorg)', pls[3].title
		assert_equal 'Ambient Galaxy (Disco Valley Mix)', pls[6].title
		assert_equal 'Soundform', pls[7].title

		assert_raise(RuntimeError) {@mpd.move(999,1)}

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.move(3,1)}
	end

	def test_moveid
		@mpd.connect

		assert @mpd.load('Astral_Projection_-_Dancing_Galaxy')

		assert @mpd.moveid( 10, 1 )

		pls = @mpd.playlist

		assert_equal 'Dancing Galaxy', pls[0].title
		assert_equal 'No One Ever Dreams', pls[1].title
		assert_equal 'Soundform', pls[2].title
		assert_equal 'Flying Into A Star', pls[3].title

		assert @mpd.moveid( 8, 7 )

		pls = @mpd.playlist

		assert_equal 'No One Ever Dreams', pls[1].title
		assert_equal 'Flying Into A Star', pls[2].title
		assert_equal 'Cosmic Ascension (ft. DJ Jorg)', pls[3].title
		assert_equal 'Ambient Galaxy (Disco Valley Mix)', pls[6].title
		assert_equal 'Soundform', pls[7].title

		assert_raise(RuntimeError) {@mpd.moveid(999,1)}

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.moveid(10,1)}

	end

	def test_next
		@mpd.connect

		@mpd.load 'Astral_Projection_-_Dancing_Galaxy'

		@mpd.play 3

		pos = @mpd.status['song'].to_i

		assert @mpd.next

		assert_equal pos + 1, @mpd.status['song'].to_i

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.next}
	end

	def test_pause
		@mpd.connect
		assert @mpd.connected?

		@mpd.load 'Astral_Projection_-_Dancing_Galaxy'

		assert @mpd.play
		assert @mpd.playing?

		@mpd.pause = true
		assert @mpd.paused?

		@mpd.pause = false
		assert !@mpd.paused?

		assert @mpd.stop
		assert @mpd.stopped?

		@mpd.pause = true
		assert @mpd.stopped?

		assert !@mpd.paused?

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.pause = true}
		assert_raise(RuntimeError) {@mpd.paused?}
	end

	def test_password
		@mpd.connect

		assert_raise(RuntimeError) {@mpd.password('wrong')}

		assert @mpd.password('test')

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.password('test')}
	end

	def test_ping
		@mpd.connect

		assert @mpd.ping
		
		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.ping}
	end

	def test_play
		@mpd.connect
		assert @mpd.connected?

		@mpd.load 'Astral_Projection_-_Dancing_Galaxy'

		assert @mpd.play

		sleep 2

		assert @mpd.playing?

		song = @mpd.current_song

		assert_equal 'Dancing Galaxy', song.title

		assert @mpd.play(2)

		sleep 2

		assert @mpd.playing?

		song = @mpd.current_song

		assert_equal 'Flying Into A Star', song.title

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.play}
		assert_raise(RuntimeError) {@mpd.playing?}
	end

	def test_playid
		@mpd.connect
		assert @mpd.connected?

		@mpd.load 'Astral_Projection_-_Dancing_Galaxy'

		assert @mpd.playid

		sleep 2

		assert @mpd.playing?

		song = @mpd.current_song

		assert_equal 'Dancing Galaxy', song.title

		assert @mpd.playid(9)

		sleep 2

		assert @mpd.playing?

		song = @mpd.current_song

		assert_equal 'Flying Into A Star', song.title

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.playid}
		assert_raise(RuntimeError) {@mpd.playing?}

	end

	def test_playlist_version
		@mpd.connect

		ver = @mpd.playlist_version

		assert_equal 1, ver

		assert @mpd.load('Astral_Projection_-_Dancing_Galaxy')

		ver = @mpd.playlist_version

		assert_equal 9, ver

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.playlist_version}
	end

	def test_playlist
		@mpd.connect

		pls = @mpd.playlist

		assert_equal 0, pls.size

		assert @mpd.load('Astral_Projection_-_Dancing_Galaxy')

		pls = @mpd.playlist

		assert_equal 8, pls.size

		assert_equal 'Dancing Galaxy', pls[0].title
		assert_equal 'Soundform', pls[1].title
		assert_equal 'Flying Into A Star', pls[2].title
		assert_equal 'No One Ever Dreams', pls[3].title
		assert_equal 'Cosmic Ascension (ft. DJ Jorg)', pls[4].title
		assert_equal 'Life On Mars', pls[5].title
		assert_equal 'Liquid Sun', pls[6].title
		assert_equal 'Ambient Galaxy (Disco Valley Mix)', pls[7].title

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.playlist}
	end

	def test_song_at_pos
		@mpd.connect

		assert @mpd.load('Astral_Projection_-_Dancing_Galaxy')

		assert_equal 'Dancing Galaxy', @mpd.song_at_pos(0).title
		assert_equal 'Soundform', @mpd.song_at_pos(1).title
		assert_equal 'Flying Into A Star', @mpd.song_at_pos(2).title
		assert_equal 'No One Ever Dreams', @mpd.song_at_pos(3).title
		assert_equal 'Cosmic Ascension (ft. DJ Jorg)', @mpd.song_at_pos(4).title
		assert_equal 'Life On Mars', @mpd.song_at_pos(5).title
		assert_equal 'Liquid Sun', @mpd.song_at_pos(6).title
		assert_equal 'Ambient Galaxy (Disco Valley Mix)', @mpd.song_at_pos(7).title

		assert_raise(RuntimeError) {@mpd.song_at_pos(999)}

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.song_at_pos(0)}
	end

	def test_song_with_id
		@mpd.connect

		assert @mpd.load('Astral_Projection_-_Dancing_Galaxy')

		assert_equal 'Dancing Galaxy', @mpd.song_with_id(7).title
		assert_equal 'Soundform', @mpd.song_with_id(8).title
		assert_equal 'Flying Into A Star', @mpd.song_with_id(9).title
		assert_equal 'No One Ever Dreams', @mpd.song_with_id(10).title
		assert_equal 'Cosmic Ascension (ft. DJ Jorg)', @mpd.song_with_id(11).title
		assert_equal 'Life On Mars', @mpd.song_with_id(12).title
		assert_equal 'Liquid Sun', @mpd.song_with_id(13).title
		assert_equal 'Ambient Galaxy (Disco Valley Mix)', @mpd.song_with_id(14).title

		assert_raise(RuntimeError) {@mpd.song_with_id(999)}

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.song_with_id(10)}
	end

	def test_playlist_changes
		@mpd.connect

		assert @mpd.add('Astral_Projection')

		changes = @mpd.playlist_changes 8

		assert_equal 1, changes.size
		assert_equal 'Ambient Galaxy (Disco Valley Mix)', changes[0].title

		changes = @mpd.playlist_changes 1

		assert_equal 8, changes.size
		assert_equal 'Dancing Galaxy', changes[0].title
		assert_equal 'Soundform', changes[1].title
		assert_equal 'Flying Into A Star', changes[2].title
		assert_equal 'No One Ever Dreams', changes[3].title
		assert_equal 'Cosmic Ascension (ft. DJ Jorg)', changes[4].title
		assert_equal 'Life On Mars', changes[5].title
		assert_equal 'Liquid Sun', changes[6].title
		assert_equal 'Ambient Galaxy (Disco Valley Mix)', changes[7].title

		changes = @mpd.playlist_changes 999

		assert_equal 8, changes.size

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.playlist_changes(9)}
	end

	def test_previous
		@mpd.connect

		@mpd.load 'Astral_Projection_-_Dancing_Galaxy'

		@mpd.play 3

		sleep 2

		assert @mpd.playing?

		pos = @mpd.status['song'].to_i

		assert @mpd.previous

		assert_equal pos - 1, @mpd.status['song'].to_i

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.previous}
	end

	def test_random
		@mpd.connect

		@mpd.random = true
		assert @mpd.random?

		@mpd.random = false
		assert !@mpd.random?

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.random = false}
		assert_raise(RuntimeError) {@mpd.random?}
	end

	def test_repeat
		@mpd.connect

		@mpd.repeat = true
		assert @mpd.repeat?

		@mpd.repeat = false
		assert !@mpd.repeat?

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.repeat = false}
		assert_raise(RuntimeError) {@mpd.repeat?}
	end

	def test_rm
		@mpd.connect

		assert @mpd.rm('Astral_Projection_-_Dancing_Galaxy')

		pls = @mpd.playlists

		assert 1, pls.size

		assert_equal 'Shpongle_-_Are_You_Shpongled', pls[0]

		assert_raise(RuntimeError) {@mpd.rm('Not-Exist')}

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.rm('Astral_Projection_-_Dancing_Galaxy')}
	end

	def test_save
		@mpd.connect

		assert @mpd.load('Astral_Projection_-_Dancing_Galaxy')
		assert @mpd.load('Shpongle_-_Are_You_Shpongled')

		assert @mpd.save('UnitTests')

		assert @mpd.clear

		assert @mpd.load('UnitTests')

		pls = @mpd.playlist

		assert_equal 15, pls.size

		assert_equal 'Dancing Galaxy', pls[0].title
		assert_equal 'Soundform', pls[1].title
		assert_equal 'Flying Into A Star', pls[2].title
		assert_equal 'No One Ever Dreams', pls[3].title
		assert_equal 'Cosmic Ascension (ft. DJ Jorg)', pls[4].title
		assert_equal 'Life On Mars', pls[5].title
		assert_equal 'Liquid Sun', pls[6].title
		assert_equal 'Ambient Galaxy (Disco Valley Mix)', pls[7].title
		assert_equal 'Shpongle Falls', pls[8].title
		assert_equal 'Monster Hit', pls[9].title
		assert_equal 'Vapour Rumours', pls[10].title
		assert_equal 'Shpongle Spores', pls[11].title
		assert_equal 'Behind Closed Eyelids', pls[12].title
		assert_equal 'Divine Moments of Truth', pls[13].title
		assert_equal '... and the Day Turned to Night', pls[14].title

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.save('test')}
	end

	def test_search
		@mpd.connect

		a = @mpd.search 'album', 'ydroponic gar'

		assert_equal 11, a.size
		a.each do |song|
			assert_equal 'Carbon Based Lifeforms', song.artist
			assert_equal 'Hydroponic Garden', song.album
		end

		b = @mpd.search 'artist', 'hpon'

		assert_equal 27, b.size
		b.each do |song|
			assert_equal 'Shpongle', song.artist
		end

		c = @mpd.search 'title', 'falls'
		assert_equal 1, c.size
		assert_equal 'Shpongle', c[0].artist
		assert_equal 'Shpongle Falls', c[0].title
		assert_equal 'Are You Shpongled?', c[0].album

		d = @mpd.search 'filename', 'disco_valley'
		assert_equal 1, d.size
		assert_equal 'Astral Projection', d[0].artist
		assert_equal 'Dancing Galaxy', d[0].album
		assert_equal 'Ambient Galaxy (Disco Valley Mix)', d[0].title

		z = @mpd.search 'title', 'no-title'
		assert_equal 0, z.size

		assert_raise(RuntimeError) {@mpd.search('error', 'nosuch')}

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.search('artist','searching')}
	end

	def test_seek
		@mpd.connect

		assert @mpd.load('Astral_Projection_-_Dancing_Galaxy')

		assert @mpd.play

		sleep 2
		
		assert @mpd.pause = true

		sleep 2

		assert @mpd.seek(2, 200)

		sleep 2

		song = @mpd.current_song

		assert_equal 'Flying Into A Star', song.title
		
		status = @mpd.status

		assert_equal '200:585', status['time']

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.seek(1, 100)}
	end

	def test_seekid
		@mpd.connect

		assert @mpd.load('Astral_Projection_-_Dancing_Galaxy')

		assert @mpd.play

		sleep 2
		
		assert @mpd.pause = true

		sleep 2

		assert @mpd.seekid(9, 200)

		sleep 2

		song = @mpd.current_song

		assert_equal 'Flying Into A Star', song.title
		
		status = @mpd.status

		assert_equal '200:585', status['time']

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.seekid(1, 100)}
	end

	def test_volume
		@mpd.connect
		
		vol = @mpd.volume

		@mpd.volume = 30
		assert_equal 30, @mpd.volume

		@mpd.volume = vol
		assert_equal vol, @mpd.volume

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.volume = 10}
		assert_raise(RuntimeError) {@mpd.volume}
	end

	def test_shuffle
		@mpd.connect

		assert @mpd.load('Astral_Projection_-_Dancing_Galaxy')

		assert @mpd.shuffle

		pls = @mpd.playlist

		assert_equal 8, pls.size
		assert_not_equal 'Dancing Galaxy', pls[0].title

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.shuffle}
	end

	def test_stats
		@mpd.connect

		stats = @mpd.stats

		assert_equal '3', stats['artists']
		assert_equal '4', stats['albums']
		assert_equal '46', stats['songs']
		assert_equal '500', stats['uptime']

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.stats}
	end

	def test_status
		@mpd.connect

		status = @mpd.status

		assert_equal 'stop', status['state']
		assert_equal '0', status['repeat']
		assert_equal '0', status['random']

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.status}
	end

	def test_stop
		@mpd.connect
		assert @mpd.connected?

		assert @mpd.load('Astral_Projection_-_Dancing_Galaxy')

		assert @mpd.play
		assert @mpd.playing?

		assert @mpd.stop
		assert @mpd.stopped?

		assert !@mpd.playing?

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.stop}
		assert_raise(RuntimeError) {@mpd.stopped?}
	end

	def test_swap
		@mpd.connect

		assert @mpd.load('Astral_Projection_-_Dancing_Galaxy')

		assert @mpd.swap(2,5)

		pls = @mpd.playlist

		assert_equal 'Dancing Galaxy', pls[0].title
		assert_equal 'Soundform', pls[1].title
		assert_equal 'Flying Into A Star', pls[5].title
		assert_equal 'No One Ever Dreams', pls[3].title
		assert_equal 'Cosmic Ascension (ft. DJ Jorg)', pls[4].title
		assert_equal 'Life On Mars', pls[2].title
		assert_equal 'Liquid Sun', pls[6].title
		assert_equal 'Ambient Galaxy (Disco Valley Mix)', pls[7].title

		assert @mpd.swap(7,1)

		pls = @mpd.playlist

		assert_equal 'Dancing Galaxy', pls[0].title
		assert_equal 'Soundform', pls[7].title
		assert_equal 'Flying Into A Star', pls[5].title
		assert_equal 'No One Ever Dreams', pls[3].title
		assert_equal 'Cosmic Ascension (ft. DJ Jorg)', pls[4].title
		assert_equal 'Life On Mars', pls[2].title
		assert_equal 'Liquid Sun', pls[6].title
		assert_equal 'Ambient Galaxy (Disco Valley Mix)', pls[1].title

		assert_raise(RuntimeError) {@mpd.swap(999,1)}

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.swap(2, 5)}
	end

	def test_swapid
		@mpd.connect

		assert @mpd.load('Astral_Projection_-_Dancing_Galaxy')

		assert @mpd.swapid(9,12)

		pls = @mpd.playlist

		assert_equal 'Dancing Galaxy', pls[0].title
		assert_equal 'Soundform', pls[1].title
		assert_equal 'Flying Into A Star', pls[5].title
		assert_equal 'No One Ever Dreams', pls[3].title
		assert_equal 'Cosmic Ascension (ft. DJ Jorg)', pls[4].title
		assert_equal 'Life On Mars', pls[2].title
		assert_equal 'Liquid Sun', pls[6].title
		assert_equal 'Ambient Galaxy (Disco Valley Mix)', pls[7].title

		assert @mpd.swapid(14,8)

		pls = @mpd.playlist

		assert_equal 'Dancing Galaxy', pls[0].title
		assert_equal 'Soundform', pls[7].title
		assert_equal 'Flying Into A Star', pls[5].title
		assert_equal 'No One Ever Dreams', pls[3].title
		assert_equal 'Cosmic Ascension (ft. DJ Jorg)', pls[4].title
		assert_equal 'Life On Mars', pls[2].title
		assert_equal 'Liquid Sun', pls[6].title
		assert_equal 'Ambient Galaxy (Disco Valley Mix)', pls[1].title

		assert_raise(RuntimeError) {@mpd.swapid(999,8)}

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.swapid(9, 12)}
	end

	def test_update
		@mpd.connect

		ret = @mpd.update

		assert_equal 1, ret

		status = @mpd.status
		
		assert_equal '1', status['updating_db']

		status = @mpd.status

		assert_nil status['updating_db']

		@mpd.disconnect
		assert_raise(RuntimeError) {@mpd.update}
	end
end
