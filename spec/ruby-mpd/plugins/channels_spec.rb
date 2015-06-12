require 'spec_helper'
require_relative '../../../lib/ruby-mpd'

RSpec.describe MPD::Plugins::Channels do
  subject { MPD.new }

  describe "#subscribe" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:subscribe, 'channel')
      subject.subscribe('channel')
    end
  end

  describe "#unsubscribe" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:unsubscribe, 'channel')
      subject.unsubscribe('channel')
    end
  end

  describe "#channels" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:channels)
      subject.channels
    end
  end

  describe "#readmessages" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:readmessages)
      subject.readmessages
    end
  end

  describe "#sendmessage" do
    it "should send correct params" do
      expect(subject).to receive(:send_command)
        .with(:sendmessage, 'channel', 'message')
      subject.sendmessage('channel', 'message')
    end
  end

end