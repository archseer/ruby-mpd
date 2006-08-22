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
		@the_playlist = []
	end

	def serve( sock )
		close = false
		while !close and line = sock.gets
			line.strip!
			args = line.split
			cmd = args[0]
			args.shift
			case cmd
				when 'add'
					if args.length == 0
						# Add the entire database
					else
						# Add a single entry
					end
					# @status[:playlist] += 1 for each song added
					sock.puts 'todo'
				when 'clear'
					self.args_check( sock, cmd, args, 0 ) do
						@status[:playlist] += 1
						sock.puts 'todo'
					end
				when 'clearerror'
					self.args_check( sock, cmd, args, 0 ) do
						sock.puts 'todo'
					end
				when 'close'
					self.args_check( sock, cmd, args, 0 ) do
						sock.puts 'todo'
						close = true
					end
				when 'crossfade'
					self.args_check( sock, cmd, args, 1 ) do |args|
						if self.is_int(args[0]) and args[0].to_i >= 0
							@status[:xfade] = args[0].to_i
							sock.puts 'OK'
						else
							sock.puts "ACK [2@0] {crossfade} \"#{args[0]}\" is not a integer >= 0"
						end
					end
				when 'currentsong'
					self.args_check( sock, cmd, args, 0 ) do
						sock.puts 'todo'
					end
				when 'delete'
					self.args_check( sock, cmd, args, 1 ) do |args|
						if self.is_int args[0]
							# Note: args[0] < 0 will be checked for in the pls...
							@status[:playlist] += 1
							sock.puts 'todo'
						else
							sock.puts 'ACK [2@0] {delete} need a positive integer'
						end
					end
				when 'deleteid'
					self.args_check( sock, cmd, args, 1 ) do |args|
						if self.is_int args[0]
							# Note: args[0] < 0 will be checked for as a song id...
							@status[:playlist] += 1
							sock.puts 'todo'
						else
							sock.puts 'ACK [2@0] {deleteid} need a positive integer'
						end
					end
				when 'find'
					self.args_check( sock, cmd, args, 2 ) do |args|
						if args[0] != 'album' and args[0] != 'artist' and args[0] != 'title'
							sock.puts 'ACK [2@0] {find} unknown table'
						else
							sock.puts 'todo'
						end
					end
				when 'kill'
					self.args_check( sock, cmd, args, 0 ) do
						sock.puts 'todo'
					end
				when 'list'
					self.args_check( sock, cmd, args, 1..2 ) do |args|
						if args[0] != 'album' and args[0] != 'artist'
							sock.puts 'ACK [2@0] {list} unknown table'
						elsif args[0] == 'artist' and args.length > 1
							sock.puts 'ACK [2@0] {list} artist table takes no args'
						else
							if args[0] == 'artist'
								# List all Artists
								listed = []
								@songs.each do |song|
									if not song['artist'].nil? and !listed.include? song['artist']
										sock.puts "Artist: #{song['artist']}"
										listed << song['artist']
									end
								end
								sock.puts 'OK'
							else
								if args.length == 2
									# List all Albums by Artist
									# artist == args[1]
									listed = []
									@songs.each do |song|
										if song['artist'] == args[1]
											if not song['album'].nil? and !listed.include? song['album']
												socks.puts "Album: #{song['album']}"
												listed << song['album']
											end
										end
									end
									sock.puts 'todo'
								else
									# List all Albums
									listed = []
									@songs.each do |song|
										if not song['album'].nil? and !listed.include? song['album']
											sock.puts "Album: #{song['album']}"
											listed << song['album']
										end
									end
									sock.puts 'OK'
								end
							end
						end
					end
				when 'listall'
					self.args_check( sock, cmd, args, 0..1 ) do |args|
						sock.puts 'todo'
					end
				when 'listallinfo'
					self.args_check( sock, cmd, args, 0..1 ) do |args|
						sock.puts 'todo'
					end
				when 'load'
					self.args_check( sock, cmd, args, 0 ) do
						# @status[:playlist] += 1 for each song loaded
						sock.puts 'todo'
					end
				when 'lsinfo'
					self.args_check( sock, cmd, args, 0..1 ) do
						sock.puts 'todo'
					end
				when 'move'
					self.args_check( sock, cmd, args, 2 ) do |args|
						if !self.is_int args[0]
							sock.puts "ACK [2@0] {move} \"#{args[0]}\" is not a integer"
						elsif !self.is_int args[1]
							sock.puts "ACK [2@0] {move} \"#{args[1]}\" is not a integer"
						else
							# Note: negative args should be checked
							@status[:playlist] += 1
							sock.puts 'todo'
						end
					end
				when 'moveid'
					self.args_check( sock, cmd, args, 2 ) do |args|
						if !self.is_int args[0]
							sock.puts "ACK [2@0] {moveid} \"#{args[0]}\" is not a integer"
						elsif !self.is_int args[1]
							sock.puts "ACK [2@0] {moveid} \"#{args[1]}\" is not a integer"
						else
							# Note: negative args should be checked
							@status[:playlist] += 1
							sock.puts 'todo'
						end
					end
				when 'next'
					self.args_check( sock, cmd, args, 0 ) do
						sock.puts 'todo'
					end
				when 'pause'
					self.args_check( sock, cmd, args, 1 ) do |args|
						if self.is_bool args[0]
							sock.puts 'todo'
						else
							sock.puts "ACK [2@0] {pause} \"#{args[0]}\" is not 0 or 1"
						end
					end
				when 'password'
					self.args_check( sock, cmd, args, 1 ) do |args|
						sock.puts 'todo'
					end
				when 'ping'
					self.args_check( sock, cmd, args, 0 ) do
						sock.puts 'OK'
					end
				when 'play'
					self.args_check( sock, cmd, args, 0..1 ) do |args|
						if args.length > 0 and !self.is_int(args[0])
							sock.puts 'ACK [2@0] {play} need a positive integer'
						else
							# Note: args[0] < 0 is checked to exist in pls...
							# but -1 seems to just return OK...
							sock.puts 'todo'
						end
					end
				when 'playid'
					self.args_check( sock, cmd, args, 0..1 ) do |args|
						if args.length > 0 and !self.is_int(args[0])
							sock.puts 'ACK [2@0] {playid} need a positive integer'
						else
							# Note: args[0] < 0 is checked to exist as a songid
							# but -1 seems to just return OK...
							sock.puts 'todo'
						end
					end
				when 'playlist'
					self.log 'MPD Warning: Call to Deprecated API: "playlist"'
					self.args_check( sock, cmd, args, 0 ) do
						sock.puts 'todo'
					end
				when 'playlistinfo'
					self.args_check( sock, cmd, args, 0..1 ) do |args|
						if args.length > 0 and !self.is_int(args[0])
							sock.puts 'ACK [2@0] {playlistinfo} need a positive integer'
						else
							# Note: args[0] < 0 just return OK...
							sock.puts 'todo'
						end
					end
				when 'playlistid'
					self.args_check( sock, cmd, args, 0..1 ) do |args|
						if args.length > 0 and !self.is_int(args[0])
							sock.puts 'ACK [2@0] {playlistid} need a positive integer'
						else
							# Note: args[0] < 0 just return OK...
							sock.puts 'todo'
						end
					end
				when 'plchanges'
					self.args_check( sock, cmd, args, 1 ) do |args|
						if args.length > 0 and !self.is_int(args[0])
							sock.puts 'ACK [2@0] {plchanges} need a positive integer'
						else
							# Note: args[0] < 0 just return OK...
							sock.puts 'todo'
						end
					end
				when 'plchangesposid'
					self.args_check( sock, cmd, args, 1 ) do |args|
						# Note: my server doesn't seem to implement it yet
						sock.puts 'todo'
					end
				when 'previous'
					self.args_check( sock, cmd, args, 0 ) do
						sock.puts 'todo'
					end
				when 'random'
					self.args_check( sock, cmd, args, 1 ) do |args|
						if self.is_bool args[0]
							@status[:random] = args[0].to_i
							sock.puts 'OK'
						elsif self.is_int args[0]
							sock.puts "ACK [2@0] {pause} \"#{args[0]}\" is not 0 or 1"
						else
							sock.puts 'ACK [2@0] {random} need an integer'
						end
					end
				when 'repeat'
					self.args_check( sock, cmd, args, 1 ) do |args|
						if self.is_bool args[0]
							@status[:repeat] = args[0].to_i
							sock.puts 'OK'
						elsif self.is_int args[0]
							sock.puts "ACK [2@0] {repeat} \"#{args[0]}\" is not 0 or 1"
						else
							sock.puts 'ACK [2@0] {repeat} need an integer'
						end
					end
				when 'rm'
					self.args_check( sock, cmd, args, 1 ) do |args|
						sock.puts 'todo'
					end
				when 'save'
					self.args_check( sock, cmd, args, 1 ) do |args|
						sock.puts 'todo'
					end
				when 'search'
					self.args_check( sock, cmd, args, 2 ) do |args|
						if args[0] != 'title' and args[0] != 'artist' and args[0] != 'album' and args[0] != 'filename'
							sock.puts 'ACK [2@0] {search} unknown table'
						else
							sock.puts 'todo'
						end
					end
				when 'seek'
					self.args_check( sock, cmd, args, 2 ) do |args|
						if !self.is_int args[0]
							sock.puts "ACK [2@0] {seek} \"#{args[0]}\" is not a integer"
						elsif !self.is_int args[1]
							sock.puts "ACK [2@0] {seek} \"#{args[1]}\" is not a integer"
						else
							# Note: arg[0] < 0 is checked as a song pos
							# arg[1] < 0 causes the song to start from the beginning
							sock.puts 'todo'
						end
					end
				when 'seekid'
					self.args_check( sock, cmd, args, 2 ) do |args|
						if !self.is_int args[0]
							sock.puts "ACK [2@0] {seekid} \"#{args[0]}\" is not a integer"
						elsif !self.is_int args[1]
							sock.puts "ACK [2@0] {seekid} \"#{args[1]}\" is not a integer"
						else
							# See above notes
							sock.puts 'todo'
						end
					end
				when 'setvol'
					self.args_check( sock, cmd, args, 1 ) do |args|
						if !self.is_int args[0]
							sock.puts 'ACK [2@0] {setvol} need an integer'
						else
							# Note: args[0] < 0 actually sets the vol val to < 0
							@status[:volume] = args[0].to_i
							sock.puts 'OK'
						end
					end
				when 'shuffle'
					self.args_check( sock, cmd, args, 0 ) do
						@status[:playlist] += 1
						sock.puts 'todo'
					end
				when 'stats'
					self.args_check( sock, cmd, args, 0 ) do
						sock.puts 'todo'
					end
				when 'status'
					self.args_check( sock, cmd, args, 0 ) do
						@status.each_pair do |key,val|
							sock.puts "#{key}: #{val}"
						end
						sock.puts "playlistlength: #{@the_playlist.length}"
						sock.puts 'OK'
					end
				when 'stop'
					self.args_check( sock, cmd, args, 0 ) do
						sock.puts 'todo'
					end
				when 'swap'
					self.args_check( sock, cmd, args, 2 ) do |args|
						if !self.is_int args[0]
							sock.puts "ACK [2@0] {swap} \"#{args[0]}\" is not a integer"
						elsif !self.is_int args[1]
							sock.puts "ACK [2@0] {swap} \"#{args[1]}\" is not a integer"
						else
							# Note: args[0] < 0 are checked as valid song posititions...
							@status[:playlist] += 1
							sock.puts 'todo'
						end
					end
				when 'swapid'
					self.args_check( sock, cmd, args, 2 ) do |args|
						if !self.is_int args[0]
							sock.puts "ACK [2@0] {swapid} \"#{args[0]}\" is not a integer"
						elsif !self.is_int args[1]
							sock.puts "ACK [2@0] {swapid} \"#{args[1]}\" is not a integer"
						else
							# Note: args[0] < 0 are checked as valid songids...
							@status[:playlist] += 1
							sock.puts 'todo'
						end
					end
				when 'update'
					self.args_check( sock, cmd, args, 0..1 ) do |args|
						@status[:playlist] += 1
						sock.puts 'todo'
					end
				when 'volume'
					self.log 'MPD Warning: Call to Deprecated API: "volume"'
					self.args_check( sock, cmd, args, 1 ) do |args|
						if !self.is_int args[0]
							sock.puts 'ACK [2@0] {volume} need an integer'
						else
							# Note: args[0] < 0 subtract from the volume
							@status[:volume] += args[0].to_i
							sock.puts 'OK'
						end
					end
				else
					sock.puts "ACK [5@0] {} unknown command #{cmd}"
			end # End Case cmd
		end # End while !close and line = sock.gets
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

end
