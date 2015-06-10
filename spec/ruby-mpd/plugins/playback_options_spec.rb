require 'spec_helper'
require_relative '../../../lib/ruby-mpd/plugins/playback_options'

RSpec.describe MPD::Plugins::PlaybackOptions do
  class MPD
    def send_command(command, *args); end
  end

  subject { MPD.new.extend described_class }

  context "#consume=" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:consume, 'yes')
      subject.consume = 'yes'
    end
  end

  context "#crossfade=" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:crossfade, 'yes')
      subject.crossfade = 'yes'
    end
  end

  context "#mixrampdb=" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:mixrampdb, 'yes')
      subject.mixrampdb = 'yes'
    end
  end

  context "#mixrampdelay=" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:mixrampdelay, 'yes')
      subject.mixrampdelay = 'yes'
    end
  end

  context "#random=" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:random, 'yes')
      subject.random = 'yes'
    end
  end

  context "#repeat=" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:repeat, 'yes')
      subject.repeat = 'yes'
    end
  end

  context "#volume=" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:setvol, 11)
      subject.volume = 11
    end
  end

  context "#single=" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:single, 'yes')
      subject.single = 'yes'
    end
  end

  context "#replay_gain_mode=" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:replay_gain_mode, 'yes')
      subject.replay_gain_mode = 'yes'
    end
  end

  context "#replay_gain_status" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:replay_gain_status)
      subject.replay_gain_status
    end
  end
end
