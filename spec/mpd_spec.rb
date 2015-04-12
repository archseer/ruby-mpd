require 'spec_helper'

describe MPD do
  it 'has a version number' do
    expect(MPD::VERSION).not_to be nil
  end

  describe "defaults" do
    it 'has sensible default settings' do
      expect(subject.hostname).to eql('localhost')
      expect(subject.port).to eql(6600)
    end
  end

end
