class MPD
  # This namespace contains "plugins", which get included into the main class.
  module Plugins
    # = Client to client commands
    #
    # Clients can communicate with each others over "channels". A channel
    # is created by a client subscribing to it. More than one client can be
    # subscribed to a channel at a time; all of them will receive the messages
    # which get sent to it.
    #
    # Each time a client subscribes or unsubscribes, the global idle event
    # subscription is generated. In conjunction with the channels command, this
    # may be used to auto-detect clients providing additional services.
    #
    # New messages are indicated by the message idle event.
    module Channels

      # Subscribe to a channel. The channel is created if it does not exist already.
      # The name may consist of alphanumeric ASCII characters plus underscore, dash, dot and colon.
      # @param [Symbol, String] channel The channel to subscribe to.
      # @macro returnraise
      def subscribe(channel)
        send_command :subscribe, channel
      end

      # Unsubscribe from a channel.
      # @param [Symbol, String] channel The channel to unsibscribe from.
      # @macro returnraise
      def unsubscribe(channel)
        send_command :unsubscribe, channel
      end

      # Obtain a list of all channels.
      # @return [Array<String>] a list of channels
      def channels
        send_command :channels
      end

      # Reads messages for this client. The response is an array of
      # hashes with +:channel+ and +:message+ keys or true if no messages.
      # @return [Array<Hash>] Messages recieved.
      def readmessages
        send_command :readmessages
      end

      # Send a message to the specified channel.
      # @param [Symbol, String] channel The channel to send to.
      # @param [String] message The message to send.
      # @macro returnraise
      def sendmessage(channel, message)
        send_command :sendmessage, channel, message
      end
    end
  end
end
