require 'spec_helper'
require_relative '../../../lib/ruby-mpd'

RSpec.describe MPD::Plugins::Controls do
  subject { MPD.new }

  describe "#next" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:next)
      subject.next
    end
  end

  describe "#pause=" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:pause, 'yes')
      subject.pause = 'yes'
    end
  end

  describe "#play" do
    context "when pos is a Hash" do
      context "with the correct key" do
        let(:pos) { { id: 32 } }

        it "should send correct params" do
          expect(subject).to receive(:send_command).with(:playid, pos[:id])
          subject.play(pos)
        end
      end

      context "with the correct key and priority" do
        let(:pos) { { id: 32 } }

        it "should send correct params" do
          expect(subject).to receive(:send_command).with(:playid, pos[:id])
          subject.play(pos)
        end
      end

      context "with an incorrect key" do
        let(:pos) { { incorrect: 32 } }

        it "should send correct params" do
          expect { subject.play(pos) }.to raise_error(ArgumentError, 'Only :id key is allowed!')
        end
      end
    end

    context "when pos is not a hash" do
      let(:pos) { '1' }

      it "should send correct params" do
        expect(subject).to receive(:send_command).with(:play, pos)
        subject.play(pos)
      end
    end
  end

  describe "#previous" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:previous)
      subject.previous
    end
  end

  describe "#seek" do
    context "when passed no options" do
      it "should send correct params" do
        expect(subject).to receive(:send_command).with(:seekcur, 'time')
        subject.seek('time', {})
      end
    end

    context "when passed an :id" do
      it "should send correct params" do
        expect(subject).to receive(:send_command).with(:seekid, 32, 'time')
        subject.seek('time', {id: 32})
      end
    end

    context "when passed a :pos" do
      it "should send correct params" do
        expect(subject).to receive(:send_command).with(:seek, 3, 'time')
        subject.seek('time', {pos: 3})
      end
    end
  end

  describe "#stop" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:stop)
      subject.stop
    end
  end
end
