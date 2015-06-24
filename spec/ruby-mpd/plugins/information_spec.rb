require 'spec_helper'
require_relative '../../../lib/ruby-mpd'

RSpec.describe MPD::Plugins::Information do
  subject { MPD.new }

  describe "#clearerror" do
    it "should make the correct call" do
      expect(subject).to receive(:send_command).with(:clearerror)
      subject.clearerror
    end
  end

  describe "#current_song" do
    context "when there is no currentsong" do
      it "should make the correct call" do
        expect(subject).to receive(:send_command).with(:currentsong).and_return(true)
        expect(subject.current_song).to be_nil
      end
    end

    context "when there is a currentsong" do
      let(:song) { double('song') }

      it "should make the correct call" do
        expect(MPD::Song).to receive(:new).with(subject, {}).and_return(song)
        expect(subject).to receive(:send_command).with(:currentsong).and_return({})
        expect(subject.current_song).to eql(song)
      end
    end
  end

  describe "#idle" do
    context "when we pass no args" do
      it "should make the correct call" do
        expect(subject).to receive(:send_command).with(:idle)
        subject.idle
      end
    end

    context "when we pass some args" do
      it "should make the correct call" do
        expect(subject).to receive(:send_command).with(:idle, "player", "mixer")
        subject.idle('player', 'mixer')
      end
    end
  end

  describe "#status" do
    it "should make the correct call" do
      expect(subject).to receive(:send_command).with(:status)
      subject.status
    end
  end

  describe "#stats" do
    it "should make the correct call" do
      expect(subject).to receive(:send_command).with(:stats)
      subject.stats
    end
  end

  describe "#paused?" do
    context "when paused" do
      let(:status) { { state: :pause } }

      it "should make the correct call" do
        expect(subject).to receive(:status).and_return(status)
        expect(subject.paused?).to be_truthy
      end
    end

    context "when not paused" do
      let(:status) { { state: :other } }

      it "should make the correct call" do
        expect(subject).to receive(:status).and_return(status)
        expect(subject.paused?).to be_falsey
      end
    end
  end

  describe "#playing?" do
    context "when playing" do
      let(:status) { { state: :play } }

      it "should make the correct call" do
        expect(subject).to receive(:status).and_return(status)
        expect(subject.playing?).to be_truthy
      end
    end

    context "when not playing" do
      let(:status) { { state: :other } }

      it "should make the correct call" do
        expect(subject).to receive(:status).and_return(status)
        expect(subject.playing?).to be_falsey
      end
    end
  end

  describe "#stopped?" do
    context "when stopped" do
      let(:status) { { state: :stop } }

      it "should make the correct call" do
        expect(subject).to receive(:status).and_return(status)
        expect(subject.stopped?).to be_truthy
      end
    end

    context "when not stopped" do
      let(:status) { { state: :other } }

      it "should make the correct call" do
        expect(subject).to receive(:status).and_return(status)
        expect(subject.stopped?).to be_falsey
      end
    end
  end

  describe "#volume" do
    context "when there is volume" do
      let(:status) { { volume: 11 } }

      it "should make the correct call" do
        expect(subject).to receive(:status).and_return(status)
        expect(subject.volume).to eql(status[:volume])
      end
    end

    context "when there is no volume" do
      let(:status) { {} }

      it "should make the correct call" do
        expect(subject).to receive(:status).and_return(status)
        expect(subject.volume).to be_nil
      end
    end
  end

  describe "#crossfade" do
    context "when there is crossfade" do
      let(:status) { { xfade: 11 } }

      it "should make the correct call" do
        expect(subject).to receive(:status).and_return(status)
        expect(subject.crossfade).to eql(status[:xfade])
      end
    end

    context "when there is no crossfade" do
      let(:status) { {} }

      it "should make the correct call" do
        expect(subject).to receive(:status).and_return(status)
        expect(subject.crossfade).to be_nil
      end
    end
  end

  describe "#playlist_version" do
    context "when there is playlist_version" do
      let(:status) { { playlist: 1 } }

      it "should make the correct call" do
        expect(subject).to receive(:status).and_return(status)
        expect(subject.playlist_version).to eql(status[:playlist])
      end
    end

    context "when there is no playlist_version" do
      let(:status) { {} }

      it "should make the correct call" do
        expect(subject).to receive(:status).and_return(status)
        expect(subject.playlist_version).to be_nil
      end
    end
  end

  describe "#consume?" do
    let(:status) { { consume: true } }

    it "should make the correct call" do
      expect(subject).to receive(:status).and_return(status)
      expect(subject.consume?).to eql(status[:consume])
    end
  end

  describe "#single?" do
    let(:status) { { single: true } }

    it "should make the correct call" do
      expect(subject).to receive(:status).and_return(status)
      expect(subject.single?).to eql(status[:single])
    end
  end

  describe "#random?" do
    let(:status) { { random: true } }

    it "should make the correct call" do
      expect(subject).to receive(:status).and_return(status)
      expect(subject.random?).to eql(status[:random])
    end
  end

  describe "#repeat?" do
    let(:status) { { repeat: true } }

    it "should make the correct call" do
      expect(subject).to receive(:status).and_return(status)
      expect(subject.repeat?).to eql(status[:repeat])
    end
  end
end
