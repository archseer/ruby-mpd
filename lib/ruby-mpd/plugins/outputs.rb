class MPD
  module Plugins
    # Commands related to audio output devices.
    module Outputs
      # Gives a list of all outputs
      # @return [Array<Hash>] An array of outputs.
      def outputs
        send_command :outputs
      end

      # Enables specified output.
      # @param [Integer] num Number of the output to enable.
      # @macro returnraise
      def enableoutput(num)
        send_command :enableoutput, num
      end

      # Disables specified output.
      # @param [Integer] num Number of the output to disable.
      # @macro returnraise
      def disableoutput(num)
        send_command :disableoutput, num
      end

      # Toggles specified output.
      # @param [Integer] num Number of the output to enable.
      # @macro returnraise
      def toggleoutput(num)
        send_command :toggleoutput, num
      end
    end
  end
end
