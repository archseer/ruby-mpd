require 'spec_helper'
require_relative '../../lib/ruby-mpd'

RSpec.describe MPD::Song do
  let(:mpd) { MPD.new }
  let(:options) {{
    time: [123, 300],
    date: "1972",
    file: 'music_filename.mp3',
    title: 'title',
    custom_key: 'custom'
  }}
  subject { MPD::Song.new(mpd, options) }

  describe "#==" do
    context "when given a match" do
      it {
        expect(subject == subject).to be_truthy
      }
    end
  end

  describe "#elapsed" do
    it { expect(subject.elapsed).to eql(123) }
  end

  describe "#track_length" do
    it { expect(subject.track_length).to eql(300) }
  end

  describe "#length" do
    it { expect(subject.length).to eql('5:00') }
  end

  describe "#comments" do
    it {
      expect(mpd).to receive(:send_command)
        .with(:readcomments, 'music_filename.mp3')
        .and_return('comments')
      expect(mpd).not_to receive(:send_command)
      expect(subject.comments).to eql('comments')
      expect(subject.comments).to eql('comments')
    }
  end

  describe "#to_h" do
    it {
      expect(subject.to_h).to eql({
        time: [123, 300],
        date: "1972",
        file: 'music_filename.mp3',
        title: 'title',
        artist: nil,
        album: nil,
        albumartist: nil,
        custom_key: 'custom'
      })
    }
  end

  describe "#method_missing" do
    context "when data has method" do
      it { expect(subject.custom_key).to eql('custom') }
    end

    context "when data does not have method" do
      it { expect(subject.custom_key_xxx).to be_nil }
    end

    context "when its a setter method" do
      it {
        subject.custom_key_xxx = 'xxxx'
        expect(subject.custom_key_xxx).to be_nil
      }
    end

    context "when exception raised" do
      subject { MPD::Song.new(mpd, {}) }

      it {
        expect { subject.custom_key('xxx') }.to raise_error(NoMethodError, 'custom_key')
      }
    end
  end
end
