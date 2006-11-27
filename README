# Librmpd and You #

librmpd is a simple yet powerful library for the
[Music Player Daemon](http://www.musicpd.org), written in Ruby.

## Goals ##

The goal of librmpd is to provide MPD client creators with a simple
interface that allows for the rapid development of clients. This is
accomplished by implementing a callback interface in the library itself,
rather than leaving this up to the client developer. librmpd also provides
thread safety for its calls to the server, allowing multiple threads to
make use of one socket.

## MPD Potocol ##

The Music Player Daemon protocol is implemented in the MPD class. This class
contains most of the commands used in communicating with the server. Some of
the commands were removed/modified to make the usage more transparent. Gone
are the confusing `lsinfo` and `listallinfo` variations on listing data
from the server. Instead these are replaced with straightforward methods,
such as `artists` to get all artists and `songs` to get all songs.

## Usage ##

All functionality is contained in the MPD class. Creating an instance of this
class is as simple as

    require 'rubygems'
    require 'librmpd'
    
    mpd = MPD.new 'localhost', 6600

Once you have an instance of the MPD class, start by connecting to the server:

    mpd.connect

When you are done, disconnect by calling disconnect

    mpd.disconnect

*Note*: The server may disconnect you at any time due to inactivity. This can
be fixed by enabling callbacks (see the Callbacks section) or by issuing a
`ping` command at certain intervals

Once connected, you can issue commands to talk to the server

    mpd.connect
    if mpd.stopped?
      mpd.play
    end
    song = mpd.current_song
    puts "Current Song: #{song.artist} - #{song.title}"

You can find documentation for each command [here](http://librmpd.rubyforge.org/docs)

## Callbacks ##

Callbacks are a simple way to make your client respond to events, rather that have to continuously ask the server for updates. This allows you (the client creator) to focus on displaying the data, rather that working overly hard to get it. This is done by having a background thread continuously check the server for changes. Because of this thead, enabling callbacks also means your client will stay connected to the server without having to worry about timeouts.

To make use of callbacks, the following steps are taken:

  1. Setup a method to be called when something happens. This is called the callback method.
  2. Tell librmpd about your callback method by adding it to the appropriate list of callbacks.
  3. Connect to the server with callbacks set as enabled.
  4. ???
  5. Profit!

Ok, so the first three are all you really need. Lets look at step one: Setup a method to be called when something happens. Each callback method will be given specific data relevant to that callback. For example, the state changed callback passes the new state to the callback. This means your state callback method has to be defined as taking one argument:

    class MyClient
      ...
      def my_state_callback( newstate )
        puts "MPD Changed State: #{newstate}"
      end
      ...
    end

That's it. As long as your defined method matches what the callback's requirements are, you're good to go. You can see the requirements for each callback under the CONSTANTS section [here](http://librmpd.rubyforge.org/docs/classes/MPD.html)

In step two, you have to actually inform librmpd about the callback, and which callback it belongs to. This is done by the `register_callback` method. `register_callback` takes two arguments, first, the Method object of the callback method, and second, the type of callback to register this method as. Sound complicated? its not. Using the above example callback, here's how we'd tell librmpd about it:

    client = MyClient.new
    state_cb = client.method 'my_state_callback'
    mpd.register_callback state_cb, MPD::STATE_CALLBACK

Blammo! that's it. The second line is the biggy. the `method` method returns a Method object which can then be called at some arbitrary point in time. This Method object is stored in a list inside librmpd, so whenever the state changes, all of the Method objects in that list are then informed of the change. Since they're stored in a list, this means you are free to add as many callbacks as you want, without side effects.

Finally, the easiest step. In order for callbacks to work, you must connect to the server with callbacks enabled:

    mpd.connect true

Easy as pie. The above will connect to the server like normal, but this time it will create a new thread that loops until you issue a `disconnect`. This loop checks the server, then sleeps for two tenths of a second, then loops. Because it's continuously polling the server, there's the added benefit of your client not being disconnected due to inactivity.

## Example Clients ##

Inside the release tar/zip, there is an example directory that contains two very simple clients. The first client, `rmpc.rb` behaves just like mpc. This is just a command line client that lets you issue a single command such as

    $ rmpc.rb play

and thats it. The second client, `tailmpc.rb` is a client that uses callbacks to print server information out to the console

    $ tailmpc.rb
    Starting TailMPC - Press Ctrl-D to quit
    
    MPD Status: play
    Current Song: Some Song.mp3
    ...
    MPD Status: stop

The `TIME_CALLBACK` by default is not enabled (since it would spew output every second) but can be enabled by editing the source.
