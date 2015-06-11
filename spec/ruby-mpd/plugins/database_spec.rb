require 'spec_helper'
require_relative '../../../lib/ruby-mpd'

RSpec.describe MPD::Plugins::Database do
  subject { MPD.new }

  context "#count" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:count, 'type', 'what')
      subject.count('type', 'what')
    end
  end

  context "#list" do
    context "when given all args" do
      it "should send correct params" do
        expect(subject).to receive(:send_command).with(:list, 'type', 'arg')
        subject.list('type', 'arg')
      end
    end

    context "when given one arg" do
      it "should send correct params" do
        expect(subject).to receive(:send_command).with(:list, 'type', nil)
        subject.list('type')
      end
    end
  end

  context "#files" do
    context "when given all args" do
      it "should send correct params" do
        expect(subject).to receive(:send_command).with(:listall, 'path')
        subject.files('path')
      end
    end

    context "when given one arg" do
      it "should send correct params" do
        expect(subject).to receive(:send_command).with(:listall, nil)
        subject.files
      end
    end
  end

  context "#songs" do
    context "when given all args" do
      it "should send correct params" do
        expect(subject).to receive(:send_command).with(:listallinfo, 'path').and_return('result')
        expect(subject).to receive(:build_songs_list).with('result')
        subject.songs('path')
      end
    end

    context "when given one arg" do
      it "should send correct params" do
        expect(subject).to receive(:send_command).with(:listallinfo, nil).and_return('result')
        expect(subject).to receive(:build_songs_list).with('result')
        subject.songs
      end
    end
  end
end
