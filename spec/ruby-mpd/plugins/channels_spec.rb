require 'spec_helper'
require_relative '../../../lib/ruby-mpd'

RSpec.describe MPD::Plugins::Channels do
  subject { MPD.new }

  context "#subscribe" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:subscribe, 'channel')
      subject.subscribe('channel')
    end
  end

  context "#unsubscribe" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:unsubscribe, 'channel')
      subject.unsubscribe('channel')
    end
  end

  context "#channels" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:channels)
      subject.channels
    end
  end

  context "#readmessages" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:readmessages)
      subject.readmessages
    end
  end

  context "#sendmessage" do
    it "should send correct params" do
      expect(subject).to receive(:send_command)
        .with(:sendmessage, 'channel', 'message')
      subject.sendmessage('channel', 'message')
    end
  end

end