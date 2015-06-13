require 'spec_helper'
require_relative '../../../lib/ruby-mpd'

RSpec.describe MPD::Plugins::Database do
  subject { MPD.new }

  describe "#count" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:count, 'type', 'what')
      subject.count('type', 'what')
    end
  end

  describe "#list" do
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

  describe "#files" do
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

  describe "#songs" do
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

  describe "#search" do
    context "when given all args and strict" do
      it "should send correct params" do
        expect(subject).to receive(:warn)
        expect(subject).to receive(:where).with({"type"=>"what"}, {:case_sensitive=>true, :strict=>true})
        subject.search('type', 'what', { case_sensitive: true })
      end
    end

    context "when given all args and no options" do
      it "should send correct params" do
        expect(subject).to receive(:warn)
        expect(subject).to receive(:where).with({"type"=>"what"}, {:strict=>nil})
        subject.search('type', 'what')
      end
    end
  end

  describe "#where" do
    context "when given no options" do
      it "should send correct params" do
        expect(subject).to receive(:send_command).with(:search, 'params').and_return(true)
        expect(subject.where('params', {})).to eql(true)
      end
    end

    context "when given no options and response is not true" do
      it "should send correct params" do
        expect(subject).to receive(:send_command).with(:search, 'params').and_return('xxxxx')
        expect(subject).to receive(:build_songs_list).with('xxxxx').and_return('yyyyy')
        expect(subject.where('params', {})).to eql('yyyyy')
      end
    end

    context "when given :add option" do
      it "should send correct params" do
        expect(subject).to receive(:send_command).with(:searchadd, 'params').and_return(true)
        expect(subject.where('params', {add:true})).to eql(true)
      end
    end

    context "when given :add option and :strict" do
      it "should send correct params" do
        expect(subject).to receive(:send_command).with(:findadd, 'params').and_return(true)
        expect(subject.where('params', {add:true, strict:true})).to eql(true)
      end
    end

    context "when given :add option and :strict" do
      it "should send correct params" do
        expect(subject).to receive(:send_command).with(:find, 'params').and_return(true)
        expect(subject.where('params', {strict:true})).to eql(true)
      end
    end
  end

  describe "#update" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:update, 'path')
      subject.update('path')
    end
  end

  describe "#rescan" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:rescan, 'path')
      subject.rescan('path')
    end
  end

  describe "#directories" do
    it "should send correct params" do
      expect(subject).to receive(:files).with('path').and_return({directory:'directory'})
      expect(subject.directories('path')).to eql('directory')
    end
  end

  describe "#albums" do
    it "should send correct params" do
      expect(subject).to receive(:list).with(:album, 'artist')
      subject.albums('artist')
    end
  end

  describe "#artists" do
    it "should send correct params" do
      expect(subject).to receive(:list).with(:artist)
      subject.artists
    end
  end

  describe "#songs_by_artist" do
    it "should send correct params" do
      expect(subject).to receive(:where).with(artist: 'artist')
      subject.songs_by_artist('artist')
    end
  end
end
