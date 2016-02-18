# ruby-mpd

[![Build Status](https://travis-ci.org/archSeer/ruby-mpd.svg?branch=master)](https://travis-ci.org/archSeer/ruby-mpd)
[![Code Climate](https://codeclimate.com/github/archSeer/ruby-mpd/badges/gpa.svg)](https://codeclimate.com/github/archSeer/ruby-mpd)

ruby-mpd is a powerful object-oriented client for the  [Music Player Daemon](http://www.musicpd.org), forked from librmpd. librmpd is as of writing outdated by 6 years! This library tries to act as a successor, originally using librmpd as a base, however almost all of the codebase was rewritten. ruby-mpd supports all "modern" MPD features as well as callbacks.

## MPD Protocol

The Music Player Daemon protocol is implemented inside the library. The implementation brings the entire set of features to ruby, with support of the newest protocol commands. However some commands were remapped, some were converted to objects, as I felt they fit this way much more into ruby and are more intuitive.

## Usage

Add to your `Gemfile`:

```ruby
gem 'ruby-mpd'
```

Then `bunde install`, require and make a new MPD instance:

```ruby
require ‘ruby-mpd’
mpd = MPD.new 'localhost', 6600
```

You can also omit the host and port, and it will use the defaults.

```ruby
mpd = MPD.new 'localhost'
mpd = MPD.new
```

Once you have an instance of the MPD class, connect to the server.

```ruby
mpd.connect
```

When you are done, disconnect by calling disconnect.

```ruby
mpd.disconnect
```

*Note*: In the past, one had to tackle the issue of the server possibly disconnecting the client at any time due to inactivity. Since 0.3.0, this is handled automatically via a reconnect mechanism.

Once connected, you can issue commands to talk to the server.

```ruby
mpd.connect
mpd.play if mpd.stopped?
song = mpd.current_song
puts "Current Song: #{song.artist} - #{song.title}"
```

Command documentation can be found [here](http://www.rubydoc.info/github/archSeer/ruby-mpd/master/MPD).

## Commands

Some commands require URI paths. `ruby-mpd` allows you to use `MPD::Song` objects directly and it extracts the file paths behind the scenes.

```ruby
song = mpd.songs_by_artist('Elvis Presley').first # => MPD::Song
mpd.add song
```

### Options

Some commands accept "option hashes" besides their default values. For example, `#move` accepts an ID key instead of the position:

```ruby
mpd.move(1, 10) # => move first song to position 10.
mpd.move({:id => 1}, 10) # => move the song with the ID of 1 to position 10.
```

Commands that accept ID's: `#move`, `#delete`, `#play`, `#song_priority`. `#seek` accepts both `:pos` and `:id`. *Note*: `#swap` and `#swapid` are still separate!

### Ranges

Some commands also allow ranges instead of numbers, specifying a range of songs. ruby-mpd correctly handles inclusive and exclusive ranges (`1..10` vs `1...10`). Negative range end means that we want the range to span until the end of the list.

For example, `#queue` allows us to return only a subset of the queue:

```ruby
mpd.queue.count # => 20
mpd.queue(1..10).count # => 10
mpd.queue(5..-1).count # => 15 (from 5 to the end of the range)
mpd.queue(5...-1).count # => 15 (does the same)
```

Move also allows specifying ranges to move a range of songs instead of just one.

```ruby
mpd.move 1, 10 # => move song 1 to position 10.
mpd.move 1..3, 10 # => move songs 1, 2 and 3 to position 10 (and 11 and 12).
```

Commands that support ranges: `#delete`, `#move`, `#queue`, `#song_priority`, `#shuffle`, `MPD::Playlist#load`.

## Searching

The MPD protocol supports two commands `find` and `search`, where `find` is strict and will be case sensitive, as well as return only full matches, while `search` is "loose" -- case insensitive and allow partial matches.

For ease of use, ruby-mpd encapsulates both `find` and `search` in one method, `MPD#where`.

Searching is case *loose* by default, meaning it is case insensitive, and will do partial matching. To enable *strict* matching, enable the `strict` option.

This does not work for `Playlist#searchadd`.

```ruby
mpd.where({artist: 'MyArtiSt'}, {strict: true})
```

Multiple query parameters can also be used:

```ruby
mpd.where(artist: 'Bonobo', album: 'Black Sands')
```

Query keys can be any of of the tags supported by MPD (a list can be fetched via `MPD#tags`), or one of the two special parameters: `:file` to search by full path (relative to database root), and `:any` to match against all available tags.

While searching, one can also enable the `add` option, which will automatically add the songs the query returned to the queue. In that case, the response will only return
`true`, stating that the operation was successful (instead of returning an array).

```ruby
mpd.where({artist: 'MyArtiSt'}, {strict: true, add: true})
```

### Queue searching

Queue searching works the same way (except by using `MPD#queue_where`), and it also accepts multiple search parameters (which seems to be undocumented in the MPD protocol
specification).

Same as `#where`, it is "loose" by default, and it supports a `:strict` option.

```ruby
mpd.queue_where(artist: 'James Brown', genre: 'Funk')
mpd.queue_where({artist: 'James Brown', genre: 'Funk'}, {strict: true})
```

## Playlists

Playlists are one of the objects that map the MPD commands onto a simple to use object. Instead of going trough all those function calls, passing data along to get your results, you simply use the object in an object-oriented way:

```ruby
mpd.playlists # => [MPD::Playlist, MPD::Playlist...]
playlist = mpd.playlists.first
p playlist.name # => "My playlist"
playlist.songs # => [MPD::Song, MPD::Song...]
playlist.rename('Awesomelist')
p playlist.name # => "Awesomelist"
playlist.add('awesome_track.mp3')
```

To create a new playlist, simply create a new object. The playlist will be created in the daemon's library automatically as soon as you use `#add` or `#searchadd`. There is also no save method, as playlists get 'saved' by the daemon any time you do an action on them (add, delete, rename).

```ruby
MPD::Playlist.new(mpd, 'name')
```

Currently, one also has to pass in the MPD instance, as playlists are tied to a certain connection.

## Callbacks

Callbacks are a simple way to make your client respond to events, rather that have to continuously ask the server for updates. This allows you to focus on displaying the data, rather that working overly hard to get it. This is done by having a background thread continuously check the server for changes.

To make use of callbacks, we need to:

1. Setup a callback to be called when something happens.
2. Create a MPD client instance with callbacks enabled.

Firstly, we need to create a callback block and subscribe it, so that will get triggered whenever a specific event happens. When the callback is triggered, it will also recieve the new values of the event that happened.

So how do we do this? We use the `MPD#on` method, which sets it all up for us. The argument takes a symbol with the name of the event. The function also requires a block, which is our actual callback that will get called.

```ruby
mpd.on :volume do |volume|
  puts "Volume was set to #{volume}!"
end
```

One can also use separate methods or Procs and whatnot, just pass them in as a parameter.

```ruby
# Using a Proc
proc = Proc.new { |volume| puts “Volume was set to #{volume}.” }
mpd.on :volume, &proc

# Using a method
def volume_change(value)
  puts “Volume changed to #{value}.”
end

handler = method(:volume_change)
mpd.on :volume, &handler
```

ruby-mpd supports callbacks for any of the keys returned by `MPD#status`, as well as `:connection`. Here's the full list of events, along with the variables it will return:

* *volume*: The volume level as an Integer between 0-100.
* *repeat*: true or false
* *random*: true or false
* *single*: true or false
* *consume*: true or false
* *playlist*: 31-bit unsigned Integer, the playlist version number.
* *playlistlength*: Integer, the length of the playlist
* *state*: `:play`, `:stop`, or `:pause`, state of the playback.
* *song*: An `MPD::Song` object, representing the current song.
* *songid*: playlist songid of the current song stopped on or playing.
* *nextsong*: playlist song number of the next song to be played.
* *nextsongid*: playlist songid of the next song to be played.
* *time*: Returns two integers, `elapsed` and `total`, Integers representing seconds.
* *elapsed*: Float, representing total time elapsed within the current song, but with higher accuracy.
* *bitrate*: instantaneous bitrate in kbps.
* *xfade*: crossfade in seconds
* *mixrampdb*: mixramp threshold in dB (Float)
* *mixrampdelay*: mixrampdelay in seconds
* *audio*: Returns three variables: sampleRate, bits and channels.
* *updating_db*: job id
* *error*: if there is an error, returns message here

* *connection*: Are we connected to the daemon? true or false

Note that if the callback returns more than one value, the callback needs more arguments in order to recieve those values:

```ruby
mpd.on :audio do |sampleRate, bits, channels|
  puts bits
end

# or
mpd.on :audio do |*args|
  puts args.join(‘,’)
end
```

Finally, the easiest step. In order for callbacks to work, create a MPD instance with callbacks enabled:

```ruby
MPD.new ‘localhost’, 6600, { callbacks: true }
```

Easy as pie. The above will connect to the server like normal, but this time it will create a new thread that loops until you issue a `disconnect`. This loop checks the server, then sleeps for two tenths of a second, then loops.

## Not yet implemented

This section documents the features that are missing in this library at the moment.

### Idle

To implement idle, what is needed is a lock that prevents sending commands to the daemon while waiting for the response (except `noidle`). An intermediate solution would be to queue the commands to send them later, when idle has returned the response.

Idle seems like a possible way to reimplement callbacks; make a separate connection and just use idle and when it returns, simply use idle again and again.

### Tests

There is the beginings of a test suite, that can be ran with:

```
$ bin/rspec spec/
```

The entire MPD server mock class either needs to be rewritten, or a `mpd.conf` along with a sample database and instructions for a controlled environment needs to be written.

## TODO list

* `MPD::Song`, `MPD::Directory`.
* Make stickers a mixin for `Playlist`, `Song`, `Directory`…
* Namespace queue
* Merge `where` and `queue_where`, by doing `where(..., { in_queue: true})`?
