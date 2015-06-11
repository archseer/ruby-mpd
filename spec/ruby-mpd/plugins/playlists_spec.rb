require 'spec_helper'
require_relative '../../../lib/ruby-mpd'

RSpec.describe MPD::Plugins::Playlists do
  subject { MPD.new }

  context "#playlists" do
    let(:pl1) { 'playlist1' }
    let(:pl2) { 'playlist2' }
    let(:pls) { ['opts1', 'opts2'] }

    it "should send correct params" do
      expect(MPD::Playlist).to receive(:new).with(subject, pls.first).and_return(pl1)
      expect(MPD::Playlist).to receive(:new).with(subject, pls.last).and_return(pl2)
      expect(subject).to receive(:send_command).with(:listplaylists).and_return(pls)
      expect(subject.playlists).to eql([pl1, pl2])
    end
  end
end
