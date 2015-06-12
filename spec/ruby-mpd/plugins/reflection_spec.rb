require 'spec_helper'
require_relative '../../../lib/ruby-mpd'

RSpec.describe MPD::Plugins::Reflection do
  subject { MPD.new }

  describe "#config" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:config)
      subject.config
    end
  end

  describe "#commands" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:commands)
      subject.commands
    end
  end

  describe "#notcommands" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:notcommands)
      subject.notcommands
    end
  end

  describe "#url_handlers" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:urlhandlers)
      subject.url_handlers
    end
  end

  describe "#decoders" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:decoders)
      subject.decoders
    end
  end

  describe "#tags" do
    let(:tagtypes) { ['TAG1', 'TAG2'] }
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:tagtypes).and_return(tagtypes)
      expect(subject).not_to receive(:send_command)
      expect(subject.tags).to eql(['tag1','tag2'])
      expect(subject.tags).to eql(['tag1','tag2'])
    end
  end
end
