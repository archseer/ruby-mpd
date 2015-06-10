require 'spec_helper'
require_relative '../../../lib/ruby-mpd/plugins/controls'

RSpec.describe MPD::Plugins::Controls do
  class MPD
    def send_command(command, *args); end
    def priority(); end
  end

  subject { MPD.new.extend described_class }

  context "#next" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:next)
      subject.next
    end
  end

  context "#pause=" do
    it "should send correct params" do
      expect(subject).to receive(:send_command).with(:pause, 'yes')
      subject.pause = 'yes'
    end
  end

  context "#play" do
    context "when pos is a Hash" do
      context "with the correct key" do
        let(:pos) { { id: 32 } }
        let(:priority) { 1 }

        it "should send correct params" do
          expect(subject).to receive(:priority).and_return(priority)
          expect(subject).to receive(:send_command).with(:playid, priority, pos[:id])
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
end
