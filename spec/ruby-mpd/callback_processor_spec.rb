require 'spec_helper'
require_relative '../../lib/ruby-mpd/callback_processor'

RSpec.describe MPD::CallbackProcessor do
  let(:mpd) { double('mpd') }
  subject { described_class.new(mpd) }

  describe "#process_callback_status" do
    let(:song) {
      MPD::Song.new(mpd, {
        :file=>"spotify:track:4kOy7M6eT5kYJCZxh0c6Lh", :time=>[nil, 271],
        :artist=>"Portishead", :title=>"The Rip", :album=>"Third",
        :date=>2008, :track=>4, :pos=>2, :id=>186, :albumartist=>"Portishead"
      })
    }
    let(:old_status) {
      {
        :volume=>24, :repeat=>false, :random=>false, :single=>false,
        :consume=>false, :playlist=>365, :playlistlength=>5, :xfade=>0,
        :state=>:play, :song=>song, :songid=>186, :time=>[96, 271],
        :elapsed=>96.484, :bitrate=>0
      }
    }

    context "when this is the first time running" do
      let(:status) {
        {
          :volume=>24, :repeat=>false, :random=>false, :single=>false,
          :consume=>false, :playlist=>365, :playlistlength=>5, :xfade=>0,
          :state=>:play, :song=>1, :songid=>186, :time=>[96, 271],
          :elapsed=>96.484, :bitrate=>0
        }
      }

      it "should fire all callbacks" do
        expect(mpd).to receive(:status).and_return(status)
        expect(mpd).to receive(:current_song).and_return(song)
        expect(mpd).to receive(:emit).with(:volume, 24)
        expect(mpd).to receive(:emit).with(:repeat, false)
        expect(mpd).to receive(:emit).with(:random, false)
        expect(mpd).to receive(:emit).with(:single, false)
        expect(mpd).to receive(:emit).with(:consume, false)
        expect(mpd).to receive(:emit).with(:playlist, 365)
        expect(mpd).to receive(:emit).with(:playlistlength, 5)
        expect(mpd).to receive(:emit).with(:xfade, 0)
        expect(mpd).to receive(:emit).with(:state, :play)
        expect(mpd).to receive(:emit).with(:song, song)
        expect(mpd).to receive(:emit).with(:songid, 186)
        expect(mpd).to receive(:emit).with(:time, 96, 271)
        expect(mpd).to receive(:emit).with(:elapsed, 96.484)
        expect(mpd).to receive(:emit).with(:bitrate, 0)

        expect(subject.process!).to eql(status)
      end
    end

    context "when nothing has changed" do
      let(:status) {
        {
          :volume=>24, :repeat=>false, :random=>false, :single=>false,
          :consume=>false, :playlist=>365, :playlistlength=>5, :xfade=>0,
          :state=>:play, :song=>1, :songid=>186, :time=>[96, 271],
          :elapsed=>96.484, :bitrate=>0
        }
      }

      it "should return the correct status information" do
        subject.instance_variable_set(:@old_status, old_status)
        expect(mpd).to receive(:status).and_return(status)
        expect(mpd).to receive(:current_song).and_return(song)
        expect(mpd).not_to receive(:emit)

        expect(subject.process!).to eql(status)
      end
    end

    context "when some of the attributes have changed" do
      let(:status) {
        {
          :volume=>34, :repeat=>false, :random=>false, :single=>false,
          :consume=>false, :playlist=>365, :playlistlength=>6, :xfade=>0,
          :state=>:pause, :song=>1, :songid=>186, :time=>[96, 271],
          :elapsed=>97.484, :bitrate=>0
        }
      }

      it "should return the correct status information" do
        subject.instance_variable_set(:@old_status, old_status)
        expect(mpd).to receive(:status).and_return(status)
        expect(mpd).to receive(:current_song).and_return(song)
        expect(mpd).to receive(:emit).with(:volume, 34)
        expect(mpd).to receive(:emit).with(:state, :pause)
        expect(mpd).to receive(:emit).with(:elapsed, 97.484)
        expect(mpd).to receive(:emit).with(:playlistlength, 6)

        expect(subject.process!).to eql(status)
      end
    end
  end
end
