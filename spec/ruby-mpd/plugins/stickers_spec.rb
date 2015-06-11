require 'spec_helper'
require_relative '../../../lib/ruby-mpd'

RSpec.describe MPD::Plugins::Stickers do
  subject { MPD.new }

  context "#get_sticker" do
    it "should send correct params" do
      expect(subject).to receive(:send_command)
        .with(:sticker, :get, 'type', 'uri', 'name')
      subject.get_sticker('type', 'uri', 'name')
    end
  end

  context "#set_sticker" do
    it "should send correct params" do
      expect(subject).to receive(:send_command)
        .with(:sticker, :set, 'type', 'uri', 'name', 'value')
      subject.set_sticker('type', 'uri', 'name', 'value')
    end
  end

  context "#delete_sticker" do
    context "when passed a name" do
      it "should send correct params" do
        expect(subject).to receive(:send_command)
          .with(:sticker, :delete, 'type', 'uri', 'name')
        subject.delete_sticker('type', 'uri', 'name')
      end
    end

    context "when not passed a name" do
      it "should send correct params" do
        expect(subject).to receive(:send_command)
          .with(:sticker, :delete, 'type', 'uri', nil)
        subject.delete_sticker('type', 'uri')
      end
    end
  end

  context "#list_stickers" do
    it "should send correct params" do
      expect(subject).to receive(:send_command)
        .with(:sticker, :list, 'type', 'uri')
      subject.list_stickers('type', 'uri')
    end
  end

  context "#find_sticker" do
    it "should send correct params" do
      expect(subject).to receive(:send_command)
        .with(:sticker, :find, 'type', 'uri', 'name')
      subject.find_sticker('type', 'uri', 'name')
    end
  end
end
