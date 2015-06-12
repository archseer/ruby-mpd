require 'spec_helper'
require_relative '../../../lib/ruby-mpd'

RSpec.describe MPD::Plugins::PlaybackOptions do
  subject { MPD.new }

  describe "#consume=" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:consume, 'yes')
      subject.consume = 'yes'
    end
  end

  describe "#crossfade=" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:crossfade, 'yes')
      subject.crossfade = 'yes'
    end
  end

  describe "#mixrampdb=" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:mixrampdb, 'yes')
      subject.mixrampdb = 'yes'
    end
  end

  describe "#mixrampdelay=" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:mixrampdelay, 'yes')
      subject.mixrampdelay = 'yes'
    end
  end

  describe "#random=" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:random, 'yes')
      subject.random = 'yes'
    end
  end

  describe "#repeat=" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:repeat, 'yes')
      subject.repeat = 'yes'
    end
  end

  describe "#volume=" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:setvol, 11)
      subject.volume = 11
    end
  end

  describe "#single=" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:single, 'yes')
      subject.single = 'yes'
    end
  end

  describe "#replay_gain_mode=" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:replay_gain_mode, 'yes')
      subject.replay_gain_mode = 'yes'
    end
  end

  describe "#replay_gain_status" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:replay_gain_status)
      subject.replay_gain_status
    end
  end
end
