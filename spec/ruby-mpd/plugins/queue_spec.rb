require 'spec_helper'
require_relative '../../../lib/ruby-mpd'

RSpec.describe MPD::Plugins::Queue do
  subject { MPD.new }

  describe "#queue" do
    context "when pass a limit" do
      it "should send correct params" do
        expect(subject).to receive(:send_command).with(:playlistinfo, 'limit').and_return('result')
        subject.queue('limit')
      end
    end

    context "when not passed a limit" do
      it "should send correct params" do
        expect(subject).to receive(:send_command).with(:playlistinfo, nil).and_return('result')
        subject.queue
      end
    end
  end

  describe "#add" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:add, 'path')
      subject.add('path')
    end
  end

  describe "#addid" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:addid, 'path', 1)
      subject.addid('path', 1)
    end
  end

  describe "#clear" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:clear)
      subject.clear
    end
  end

  describe "#delete" do
    context "when pos is a hash" do
      context "when we have a valid id" do
        let(:pos) { { id: 32 } }

        it "should send correct params" do
          expect(subject).to receive(:send_command).with(:deleteid, pos[:id])
          subject.delete(pos)
        end
      end

      context "when we don't have a valid id" do
        let(:pos) { { other: 32 } }

        it "should raise" do
          expect { subject.delete(pos) }.to raise_error(ArgumentError, 'Only :id key is allowed!')
        end
      end
    end

    context "when pos is not a hash" do
      let(:pos) { 'not a hash' }

      it "should send correct params" do
        expect(subject).to receive(:send_command).with(:delete, pos)
        subject.delete(pos)
      end
    end
  end

  describe "#move" do
    context "when from is a hash" do
      context "when we have a valid id" do
        let(:from) { { id: 32 } }
        let(:to) { 33 }

        it "should send correct params" do
          expect(subject).to receive(:send_command).with(:moveid, from[:id], to)
          subject.move(from, to)
        end
      end

      context "when we don't have a valid id" do
        let(:from) { { other: 32 } }
        let(:to) { 33 }

        it "should raise" do
          expect { subject.move(from,to) }.to raise_error(ArgumentError, 'Only :id key is allowed!')
        end
      end
    end

    context "when from is not a hash" do
      let(:from) { 'not a hash' }
      let(:to) { 33 }

      it "should send correct params" do
        expect(subject).to receive(:send_command).with(:move, from, to)
        subject.move(from, to)
      end
    end
  end

  describe "#song_with_id" do
    it "should send correct params" do
      expect(subject).to receive(:send_command)
        .with(:playlistid, 'songid')
        .and_return('songinfo')
      expect(MPD::Song).to receive(:new).with(subject, 'songinfo')
      subject.song_with_id('songid')
    end
  end

  describe "#queue_search" do
    context "when no options passed in" do
      it "should send correct params" do
        expect(subject).to receive(:warn)
        expect(subject).to receive(:queue_where)
          .with({'type' => 'what'}, {:strict=>nil})
        subject.queue_search('type', 'what', {})
      end
    end

    context "when :case_sensitive option passed in" do
      it "should send correct params" do
        expect(subject).to receive(:warn)
        expect(subject).to receive(:queue_where)
          .with({'type' => 'what'}, {:case_sensitive=>true, :strict=>true})
        subject.queue_search('type', 'what', {case_sensitive:true})
      end
    end
  end

  describe "#queue_where" do
    context "when passed strict" do
      it "should send correct params" do
        expect(subject).to receive(:send_command)
          .with(:playlistfind, 'params')
          .and_return('result')
        subject.queue_where('params', {strict: true})
      end
    end
  end

  describe "#queue_changes" do
    it "should send correct params" do
      expect(subject).to receive(:send_command)
        .with(:plchanges, 'version')
        .and_return('result')
      subject.queue_changes('version')
    end
  end

  describe "#song_priority" do
    context "when pos is a hash" do
      context "when we have a valid pos" do
        let(:pos) { { id: [5,6,7] } }
        let(:priority) { 10 }

        it "should send correct params" do
          expect(subject).to receive(:send_command).with(:prioid, priority, 5,6,7)
          subject.song_priority(priority, pos)
        end
      end

      context "when we don't have a valid id" do
        let(:pos) { { other: 32 } }
        let(:priority) { 10 }

        it "should raise" do
          expect { subject.song_priority(priority, pos) }.to raise_error(ArgumentError, 'Only :id key is allowed!')
        end
      end
    end

    context "when pos is not a hash" do
      let(:pos) { [5..7, 9..10] }
      let(:priority) { 10 }

      it "should send correct params" do
        expect(subject).to receive(:send_command).with(:prio, priority, 5..7, 9..10)
        subject.song_priority(priority, pos)
      end
    end
  end

  describe "#shuffle" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:shuffle, 'range')
      subject.shuffle('range')
    end
  end

  describe "#swap" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:swap, 'song1', 'song2')
      subject.swap('song1', 'song2')
    end
  end

  describe "#swapid" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:swapid, 'songid1', 'songid2')
      subject.swapid('songid1', 'songid2')
    end
  end

  describe "#save" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:save, 'playlist')
      subject.save('playlist')
    end
  end
end
