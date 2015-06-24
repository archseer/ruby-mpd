class MPD
  class CallbackProcessor
    def initialize(mpd)
      @mpd = mpd
      @cur_status = {}
      @old_status = {}
    end

    def process!
      @cur_status = @mpd.status
      @cur_status[:song] = @mpd.current_song

      @cur_status.each do |key, val|
        next if val == @old_status[key]
        @mpd.emit key, *val
      end
      @old_status = @cur_status
    end
  end
end
