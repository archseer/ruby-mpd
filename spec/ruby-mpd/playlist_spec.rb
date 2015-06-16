require 'spec_helper'
require_relative '../../lib/ruby-mpd'

RSpec.describe MPD::Playlist do
  let(:mpd) { MPD.new }
  let(:options) { { playlist: "xxxx" } }
  let(:result) { [] }
  subject { MPD::Playlist.new(mpd, options) }

  describe "#songs" do
    context "when passed an incorrect playlist" do
      before :each do
        expect(mpd).to receive(:send_command)
          .with(:listplaylistinfo, options[:playlist])
          .and_raise(MPD::NotFound)
      end

      it { expect(subject.songs).to be_empty }
    end

    context "when passed a playlist that contains unknown data" do
      before :each do
        expect(subject).to receive(:puts)
        expect(mpd).to receive(:send_command)
          .with(:listplaylistinfo, options[:playlist])
          .and_raise(TypeError)
      end

      it { expect(subject.songs).to be_empty }
    end

    # TODO this should probably be a feature test as I'm not stubbing
    # :send_command in this instance.
    #
    context "when passed a list of file identifiers" do
      let(:options) { { playlist: "June 2015" } }
      let(:response) {
        "file: spotify:track:6OGRM4MAOlyOdhHuX0OJ6P\nTime: 367\nArtist: Moderat\n" \
        "Title: A New Error\nAlbum: Moderat\nDate: 2009\nTrack: 1\n" \
        "AlbumArtist: Moderat\nfile: spotify:track:6vIMQB4hBD6ERSOCghGQkj\n" \
        "Time: 263\nArtist: Moderat\nTitle: Bad Kingdom\nAlbum: II\n" \
        "Date: 2013\nTrack: 2\nAlbumArtist: Moderat\n" \
        "file: spotify:track:1fJN1YJ7NJfrSDGprKtG0V\nTime: 272\n" \
        "Artist: Moderat\nTitle: Rusty Nails\nAlbum: Moderat\nDate: 2009\n" \
        "Track: 2\nAlbumArtist: Moderat\nfile: spotify:track:3n9JcswaEPwVz6TkRgEnBp\n" \
        "Time: 268\nArtist: Moderat\nTitle: Les Grandes Marches\nAlbum: Moderat\n" \
        "Date: 2009\nTrack: 10\nAlbumArtist: Moderat\n"
      }
      let(:ok) { "OK\n" }
      subject { MPD::Playlist.new(mpd, options) }

      before :each do
        server = double('server').as_null_object
        mpd.instance_variable_set(:@socket, server)

        expect(server).to receive(:puts)
        expect(server).to receive(:gets).and_return(response)
        expect(server).to receive(:gets).and_return(ok)
      end

      it "should return some song objects" do
        songs = subject.songs
        expect(songs).to be_a(Array)
        expect(songs.size).to eql(4)
        songs.each do |s|
          expect(s.class).to eql(MPD::Song)
        end
        expect(songs.first.title).to eql('A New Error')
        expect(songs.first.file).to eql('spotify:track:6OGRM4MAOlyOdhHuX0OJ6P')
        expect(songs.first.track_length).to eql(367)
        expect(songs.first.elapsed).to be_nil
        expect(songs.first.length).to eql('6:07')
      end
    end

    context "when passed a list of file identifiers that are http based" do
      let(:options) { { playlist: "June 2015" } }
      let(:response) {
        "file: http://12.12.12.12/xxx\nTime: 367\nArtist: Moderat\n" \
        "Title: A New Error\nAlbum: Moderat\nDate: 2009\nTrack: 1\n" \
        "AlbumArtist: Moderat\nfile: spotify:track:6vIMQB4hBD6ERSOCghGQkj\n" \
        "Time: 263\nArtist: Moderat\nTitle: Bad Kingdom\nAlbum: II\n" \
        "Date: 2013\nTrack: 2\nAlbumArtist: Moderat\n" \
        "file: spotify:track:1fJN1YJ7NJfrSDGprKtG0V\nTime: 272\n" \
        "Artist: Moderat\nTitle: Rusty Nails\nAlbum: Moderat\nDate: 2009\n" \
        "Track: 2\nAlbumArtist: Moderat\nfile: spotify:track:3n9JcswaEPwVz6TkRgEnBp\n" \
        "Time: 268\nArtist: Moderat\nTitle: Les Grandes Marches\nAlbum: Moderat\n" \
        "Date: 2009\nTrack: 10\nAlbumArtist: Moderat\n"
      }
      let(:ok) { "OK\n" }
      subject { MPD::Playlist.new(mpd, options) }

      before :each do
        server = double('server').as_null_object
        mpd.instance_variable_set(:@socket, server)

        expect(server).to receive(:puts)
        expect(server).to receive(:gets).and_return(response)
        expect(server).to receive(:gets).and_return(ok)
      end

      it "should return some song objects" do
        songs = subject.songs
        expect(songs).to be_a(Array)
        expect(songs.size).to eql(4)
        songs.each do |s|
          expect(s.class).to eql(MPD::Song)
        end
        expect(songs.first.file).to eql('http://12.12.12.12/xxx')
        expect(songs.first.track_length).to eql(0)
        expect(songs.first.elapsed).to eql(0)
        expect(songs.first.length).to eql('0:00')
      end
    end
  end

  describe "#load" do
    it "should send correct params" do
      expect(mpd).to receive(:send_command).with(:load, 'xxxx', 'range')
      subject.load('range')
    end
  end

  describe "#add" do
    it "should send correct params" do
      expect(mpd).to receive(:send_command).with(:playlistadd, 'xxxx', 'uri')
      subject.add('uri')
    end
  end

  describe "#searchadd" do
    it "should send correct params" do
      expect(mpd).to receive(:send_command).with(:searchaddpl, 'xxxx', 'type', 'what')
      subject.searchadd('type', 'what')
    end
  end

  describe "#clear" do
    it "should send correct params" do
      expect(mpd).to receive(:send_command).with(:playlistclear, 'xxxx')
      subject.clear
    end
  end

  describe "#delete" do
    it "should send correct params" do
      expect(mpd).to receive(:send_command).with(:playlistdelete, 'xxxx', 'pos')
      subject.delete('pos')
    end
  end

  describe "#move" do
    it "should send correct params" do
      expect(mpd).to receive(:send_command).with(:playlistmove, 'xxxx', 'songid', 'pos')
      subject.move('songid', 'pos')
    end
  end

  describe "#rename" do
    it "should send correct params" do
      expect(mpd).to receive(:send_command).with(:rename, 'xxxx', 'newname')
      subject.rename('newname')
      expect(subject.name).to eql('newname')
    end
  end

  describe "#destroy" do
    it "should send correct params" do
      expect(mpd).to receive(:send_command).with(:rm, 'xxxx')
      subject.destroy
    end
  end
end
