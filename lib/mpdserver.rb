require 'gserver'
require 'yaml'

class MPDTestServer < GServer

	def initialize( port, db_file = 'database.yaml', *args )
		super port, *args
		@status = {
			:volume => 0,
			:repeat => 0,
			:random => 0,
			:playlist => 0,
			:state => 'stop',
			:xfade => 0
		}
		@database = YAML::load( File.open( db_file ) )
		@songs = @database[0]
		@playlists = @database[1]
		@artists = []
		@albums = []
		@the_playlist = []
		@filetree = {:name =>'', :dirs =>[], :songs =>[]}
		@songs.each_with_index do |song,i|
			song['id'] = i
			if !song['artist'].nil? and !@artists.include? song['artist']
				@artists << song['artist']
			end
			if !song['album'].nil? and !@albums.include? song['album']
				@albums << song['album']
			end
			if !song['file'].nil?
				dirs = song['file'].split '/'
				dirs.pop
				the_dir = @filetree
				dirs.each do |d|
					found = nil
					the_dir[:dirs].each do |sub|
						if sub[:name] == d
							found = sub
							break
						end
					end
					if found.nil?
						found = {:name => d, :dirs =>[], :songs =>[]}
						the_dir[:dirs] << found
					end
					the_dir = found
				end # End dirs.each
				the_dir[:songs] << song
			end # End if !song['file'].nil?
		end # End @songs.each
	end

	def serve( sock )
		sock.puts 'OK MPD 0.11.5'
		begin
			while line = sock.gets

				args = build_args line

				cmd = args.shift

				ret = do_cmd sock, cmd, args
				if audit
					log "MPD Command \"#{cmd}(#{args.join(', ')})\": " + (ret ? 'successful' : 'failed')
				end
			end
		rescue
		end
	end

	def do_cmd( sock, cmd, args )
		case cmd
			when 'add'
				if args.length == 0
					# Add the entire database
					@songs.each do |s|
						@status[:playlist] += 1
						@the_playlist << s
					end
					return(cmd_pass(sock))
				else
					# Add a single entry
					the_song = nil
					@songs.each do |s|
						if s['file'] == args[0]
							the_song = s
							break
						end
					end

					if the_song.nil?
						dir = locate_dir(args[0])
						if not dir.nil?
							# Add the dir
							add_dir_to_pls dir
							return(cmd_pass(sock))
						else
							return(cmd_fail(sock,'ACK [50@0] {add} directory or file not found'))
						end
					else
						@status[:playlist] += 1
						@the_playlist << the_song
						return(cmd_pass(sock))
					end
				end
			when 'clear'
				args_check( sock, cmd, args, 0 ) do
					@status[:playlist] += 1
					@the_playlist = []
					return(cmd_pass(sock))
				end
			when 'clearerror'
				args_check( sock, cmd, args, 0 ) do
					@the_error = nil
					return(cmd_pass(sock))
				end
			when 'close'
				sock.close
				return true
			when 'crossfade'
				args_check( sock, cmd, args, 1 ) do |args|
					if is_int(args[0]) and args[0].to_i >= 0
						@status[:xfade] = args[0].to_i
						return(cmd_pass(sock))
					else
						return(cmd_fail(sock,"ACK [2@0] {crossfade} \"#{args[0]}\" is not a integer >= 0"))
					end
				end
			when 'currentsong'
				args_check( sock, cmd, args, 0 ) do
					sock.puts 'todo'
				end
			when 'delete'
				args_check( sock, cmd, args, 1 ) do |args|
					if is_int args[0]
						if args[0].to_i < 0 or args[0].to_i >= @the_playlist.length
							sock.puts "ACK [50@0] {delete} song doesn't exist: \"#{args[0]}\""
						else
							@the_playlist.delete_at args[0].to_i
							@status[:playlist] += 1
							return(cmd_pass(sock))
						end
					else
						sock.puts 'ACK [2@0] {delete} need a positive integer'
					end
				end
			when 'deleteid'
				args_check( sock, cmd, args, 1 ) do |args|
					if is_int args[0]
						the_song = nil
						@the_playlist.each do |song|
							if song['id'] == args[0].to_i
								the_song = song
								break
							end
						end

						if not the_song.nil?
							@the_playlist.delete the_song
							@status[:playlist] += 1
							return(cmd_pass(sock))
						else
							sock.puts "ACK [50@0] {deleteid} song id doesn't exist: \"#{args[0]}\""
						end
					else
						sock.puts 'ACK [2@0] {deleteid} need a positive integer'
					end
				end
			when 'find'
				args_check( sock, cmd, args, 2 ) do |args|
					if args[0] != 'album' and args[0] != 'artist' and args[0] != 'title'
						sock.puts 'ACK [2@0] {find} unknown table'
					else
						sock.puts 'todo'
					end
				end
			when 'kill'
				args_check( sock, cmd, args, 0 ) do
					sock.puts 'todo'
				end
			when 'list'
				args_check( sock, cmd, args, 1..2 ) do |args|
					if args[0] != 'album' and args[0] != 'artist'
						sock.puts 'ACK [2@0] {list} unknown table'
					elsif args[0] == 'artist' and args.length > 1
						sock.puts 'ACK [2@0] {list} artist table takes no args'
					else
						if args[0] == 'artist'
							# List all Artists
							@artists.each do |artist|
								sock.puts "Artist: #{artist}"
							end
							return(cmd_pass(sock))
						else
							if args.length == 2
								# List all Albums by Artist
								# artist == args[1]
								if !@artists.include? args[1]
									sock.puts "ACK [50@0] {list} artist \"#{args[1]}\" not found"
								else
									listed = []
									@songs.each do |song|
										if song['artist'] == args[1]
											if not song['album'].nil? and !listed.include? song['album']
												sock.puts "Album: #{song['album']}"
												listed << song['album']
											end
										end
									end
									return(cmd_pass(sock))
								end
							else
								# List all Albums
								@albums.each do |album|
									sock.puts "Album: #{album}"
								end
								return(cmd_pass(sock))
							end
						end
					end
				end
			when 'listall'
				args_check( sock, cmd, args, 0..1 ) do |args|
					if args.length == 0
						@filetree[:dirs].each do |d|
							send_dir sock, d, false
						end
					else
						dir = locate_dir args[0]
						if not dir.nil?
							parents = args[0].split '/'
							parents.pop
							parents = parents.join '/'
							parents += '/' unless parents.length == 0
							send_dir sock, dir, false, parents
						else
							sock.puts 'ACK [50@0] {listall} directory or file not found'
						end
					end
					return(cmd_pass(sock))
				end
			when 'listallinfo'
				args_check( sock, cmd, args, 0..1 ) do |args|
					if args.length == 0
						@filetree[:dirs].each do |d|
							send_dir sock, d, true
						end
					else
						sock.puts 'todo'
					end
					return(cmd_pass(sock))
				end
			when 'load'
				args_check( sock, cmd, args, 0 ) do
					# @status[:playlist] += 1 for each song loaded
					sock.puts 'todo'
				end
			when 'lsinfo'
				args_check( sock, cmd, args, 0..1 ) do
					sock.puts 'todo'
				end
			when 'move'
				args_check( sock, cmd, args, 2 ) do |args|
					if !is_int args[0]
						sock.puts "ACK [2@0] {move} \"#{args[0]}\" is not a integer"
					elsif !is_int args[1]
						sock.puts "ACK [2@0] {move} \"#{args[1]}\" is not a integer"
					else
						# Note: negative args should be checked
						@status[:playlist] += 1
						sock.puts 'todo'
					end
				end
			when 'moveid'
				args_check( sock, cmd, args, 2 ) do |args|
					if !is_int args[0]
						sock.puts "ACK [2@0] {moveid} \"#{args[0]}\" is not a integer"
					elsif !is_int args[1]
						sock.puts "ACK [2@0] {moveid} \"#{args[1]}\" is not a integer"
					else
						# Note: negative args should be checked
						@status[:playlist] += 1
						sock.puts 'todo'
					end
				end
			when 'next'
				args_check( sock, cmd, args, 0 ) do
					sock.puts 'todo'
				end
			when 'pause'
				args_check( sock, cmd, args, 1 ) do |args|
					if is_bool args[0]
						sock.puts 'todo'
					else
						sock.puts "ACK [2@0] {pause} \"#{args[0]}\" is not 0 or 1"
					end
				end
			when 'password'
				args_check( sock, cmd, args, 1 ) do |args|
					sock.puts 'todo'
				end
			when 'ping'
				args_check( sock, cmd, args, 0 ) do
					return(cmd_pass(sock))
				end
			when 'play'
				args_check( sock, cmd, args, 0..1 ) do |args|
					if args.length > 0 and !is_int(args[0])
						sock.puts 'ACK [2@0] {play} need a positive integer'
					else
						# Note: args[0] < 0 is checked to exist in pls...
						# but -1 seems to just return OK...
						sock.puts 'todo'
					end
				end
			when 'playid'
				args_check( sock, cmd, args, 0..1 ) do |args|
					if args.length > 0 and !is_int(args[0])
						sock.puts 'ACK [2@0] {playid} need a positive integer'
					else
						# Note: args[0] < 0 is checked to exist as a songid
						# but -1 seems to just return OK...
						sock.puts 'todo'
					end
				end
			when 'playlist'
				log 'MPD Warning: Call to Deprecated API: "playlist"' if audit
				args_check( sock, cmd, args, 0 ) do
					@the_playlist.each_with_index do |v,i|
						sock.puts "#{i}: #{v['file']}"
					end
					return(cmd_pass(sock))
				end
			when 'playlistinfo'
				args_check( sock, cmd, args, 0..1 ) do |args|
					if args.length > 0 and !is_int(args[0])
						sock.puts 'ACK [2@0] {playlistinfo} need a positive integer'
					else
						args.clear if args.length > 0 and args[0].to_i < 0
						if args.length != 0
							if args[0].to_i >= @the_playlist.length
								sock.puts "ACK [50@0] {playlistinfo} song doesn't exist: \"#{args[0]}\""
							else
								song = @the_playlist[args[0].to_i]
								sock.puts "file: #{song['file']}"
								song.each_pair do |key,val|
									sock.puts "#{key.capitalize}: #{val}" unless key == 'file'
								end
								return(cmd_pass(sock))
							end
						else
							@the_playlist.each do |song|
								sock.puts "file: #{song['file']}"
								song.each_pair do |key,val|
									sock.puts "#{key.capitalize}: #{val}" unless key == 'file'
								end
							end
							return(cmd_pass(sock))
						end
					end
				end
			when 'playlistid'
				args_check( sock, cmd, args, 0..1 ) do |args|
					if args.length > 0 and !is_int(args[0])
						sock.puts 'ACK [2@0] {playlistid} need a positive integer'
					else
						# Note: args[0] < 0 just return OK...
						sock.puts 'todo'
					end
				end
			when 'plchanges'
				args_check( sock, cmd, args, 1 ) do |args|
					if args.length > 0 and !is_int(args[0])
						sock.puts 'ACK [2@0] {plchanges} need a positive integer'
					else
						# Note: args[0] < 0 just return OK...
						sock.puts 'todo'
					end
				end
			when 'plchangesposid'
				args_check( sock, cmd, args, 1 ) do |args|
					# Note: my server doesn't seem to implement it yet
					sock.puts 'todo'
				end
			when 'previous'
				args_check( sock, cmd, args, 0 ) do
					sock.puts 'todo'
				end
			when 'random'
				args_check( sock, cmd, args, 1 ) do |args|
					if is_bool args[0]
						@status[:random] = args[0].to_i
						return(cmd_pass(sock))
					elsif is_int args[0]
						sock.puts "ACK [2@0] {pause} \"#{args[0]}\" is not 0 or 1"
					else
						sock.puts 'ACK [2@0] {random} need an integer'
					end
				end
			when 'repeat'
				args_check( sock, cmd, args, 1 ) do |args|
					if is_bool args[0]
						@status[:repeat] = args[0].to_i
						return(cmd_pass(sock))
					elsif is_int args[0]
						sock.puts "ACK [2@0] {repeat} \"#{args[0]}\" is not 0 or 1"
					else
						sock.puts 'ACK [2@0] {repeat} need an integer'
					end
				end
			when 'rm'
				args_check( sock, cmd, args, 1 ) do |args|
					sock.puts 'todo'
				end
			when 'save'
				args_check( sock, cmd, args, 1 ) do |args|
					sock.puts 'todo'
				end
			when 'search'
				args_check( sock, cmd, args, 2 ) do |args|
					if args[0] != 'title' and args[0] != 'artist' and args[0] != 'album' and args[0] != 'filename'
						sock.puts 'ACK [2@0] {search} unknown table'
					else
						sock.puts 'todo'
					end
				end
			when 'seek'
				args_check( sock, cmd, args, 2 ) do |args|
					if !is_int args[0]
						sock.puts "ACK [2@0] {seek} \"#{args[0]}\" is not a integer"
					elsif !is_int args[1]
						sock.puts "ACK [2@0] {seek} \"#{args[1]}\" is not a integer"
					else
						# Note: arg[0] < 0 is checked as a song pos
						# arg[1] < 0 causes the song to start from the beginning
						sock.puts 'todo'
					end
				end
			when 'seekid'
				args_check( sock, cmd, args, 2 ) do |args|
					if !is_int args[0]
						sock.puts "ACK [2@0] {seekid} \"#{args[0]}\" is not a integer"
					elsif !is_int args[1]
						sock.puts "ACK [2@0] {seekid} \"#{args[1]}\" is not a integer"
					else
						# See above notes
						sock.puts 'todo'
					end
				end
			when 'setvol'
				args_check( sock, cmd, args, 1 ) do |args|
					if !is_int args[0]
						sock.puts 'ACK [2@0] {setvol} need an integer'
					else
						# Note: args[0] < 0 actually sets the vol val to < 0
						@status[:volume] = args[0].to_i
						return(cmd_pass(sock))
					end
				end
			when 'shuffle'
				args_check( sock, cmd, args, 0 ) do
					@status[:playlist] += 1
					sock.puts 'todo'
				end
			when 'stats'
				args_check( sock, cmd, args, 0 ) do
					sock.puts 'todo'
				end
			when 'status'
				args_check( sock, cmd, args, 0 ) do
					@status.each_pair do |key,val|
						sock.puts "#{key}: #{val}"
					end
					sock.puts "playlistlength: #{@the_playlist.length}"
					return(cmd_pass(sock))
				end
			when 'stop'
				args_check( sock, cmd, args, 0 ) do
					sock.puts 'todo'
				end
			when 'swap'
				args_check( sock, cmd, args, 2 ) do |args|
					if !is_int args[0]
						sock.puts "ACK [2@0] {swap} \"#{args[0]}\" is not a integer"
					elsif !is_int args[1]
						sock.puts "ACK [2@0] {swap} \"#{args[1]}\" is not a integer"
					else
						# Note: args[0] < 0 are checked as valid song posititions...
						@status[:playlist] += 1
						sock.puts 'todo'
					end
				end
			when 'swapid'
				args_check( sock, cmd, args, 2 ) do |args|
					if !is_int args[0]
						sock.puts "ACK [2@0] {swapid} \"#{args[0]}\" is not a integer"
					elsif !is_int args[1]
						sock.puts "ACK [2@0] {swapid} \"#{args[1]}\" is not a integer"
					else
						# Note: args[0] < 0 are checked as valid songids...
						@status[:playlist] += 1
						sock.puts 'todo'
					end
				end
			when 'update'
				args_check( sock, cmd, args, 0..1 ) do |args|
					@status[:playlist] += 1
					sock.puts 'todo'
				end
			when 'volume'
				log 'MPD Warning: Call to Deprecated API: "volume"' if audit
				args_check( sock, cmd, args, 1 ) do |args|
					if !is_int args[0]
						sock.puts 'ACK [2@0] {volume} need an integer'
					else
						# Note: args[0] < 0 subtract from the volume
						@status[:volume] += args[0].to_i
						return(cmd_pass(sock))
					end
				end
			else
				sock.puts "ACK [5@0] {} unknown command #{cmd}"
		end # End Case cmd
	end

	def cmd_pass( sock )
		sock.puts 'OK'
		return true
	end

	def cmd_fail( sock, msg )
		sock.puts msg
		return false
	end

	def build_args( line )
		ret = []
		word = ''
		escaped = false
		in_quote = false

		line.strip!

		line.each_byte do |c|
			c = c.chr
			if c == ' ' and !in_quote
				ret << word unless word.empty?
				word = ''
			elsif c == '"' and !escaped
				if in_quote
					in_quote = false
				else
					in_quote = true
				end
				ret << word unless word.empty?
				word = ''
			else
				escaped = (c == '\\')
				word += c
			end
		end

		ret << word unless word.empty?

		return ret
	end

	def args_check( sock, cmd, argv, argc )
		if (argc.kind_of? Range and argc.include?(argv.length)) or
				(argv.length == argc)
			yield argv
		else
			sock.puts "ACK [2@0] {#{cmd}} wrong number of arguments for \"#{cmd}\""
		end
	end

	def is_int( val )
  	val =~ /^[-+]?[0-9]*$/
	end

	def is_bool( val )
		val == '0' or val == '1'
	end

	def locate_dir( path )
		dirs = path.split '/'

		the_dir = @filetree
		dirs.each do |d|
			found = nil
			the_dir[:dirs].each do |sub|
				if sub[:name] == d
					found = sub
					break
				end
			end
			if found.nil?
				return nil
			else
				the_dir = found
			end
		end

		return the_dir
	end

	def send_dir( sock, dir, allinfo, path = '' )
		sock.puts "directory: #{path}#{dir[:name]}"

		dir[:songs].each do |song|
			if allinfo
				sock.puts "file: #{song['file']}"
				song.each_pair do |key,val|
					sock.puts "#{key.capitalize}: #{val}" unless key == 'file'
				end
			else
				sock.puts "file: #{song['file']}"
			end
		end

		dir[:dirs].each do |d|
			send_dir(sock, d, allinfo, dir[:name] + '/')
		end
	end

	def add_dir_to_pls( dir )
		dir[:songs].each do |song|
			@status[:playlist] += 1
			@the_playlist << song
		end

		dir[:dirs].each do |d|
			add_dir_to_pls d
		end
	end

end
