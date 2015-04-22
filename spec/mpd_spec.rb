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

  describe '#socket' do
    let(:socket_file) { File.expand_path('../support/socket.sock',  __FILE__) }
    let(:socket) { subject.send(:socket) }
    
    context "if the hostname is a file that exists" do
      subject { MPD.new(socket_file) }

      before do
        allow(File).to receive(:exists?).with(socket_file).and_return(true)
        allow(UNIXSocket).to receive(:new).with(socket_file).and_return('unix socket stub')
      end

      it 'uses a Unix socket' do
        expect(socket).to eql('unix socket stub')
      end
    end

    context "if the hostname does NOT exist" do
      subject { MPD.new('localhost') }

      it 'uses a TCP socket' do
        expect(socket).to be_a(TCPSocket)
      end
    end
  end
end
