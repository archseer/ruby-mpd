require 'spec_helper'
require_relative '../lib/ruby-mpd'

RSpec.describe 'MPD' do
  subject { MPD.new('localhost', 6600, password: password) }
  let(:password) { nil }

  it 'has a version number' do
    expect(MPD::VERSION).not_to be nil
  end

  describe "defaults" do
    it 'has sensible default settings' do
      expect(subject.hostname).to eql('localhost')
      expect(subject.port).to eql(6600)
    end
  end

  describe '#authenticate' do
    context "with a password" do
      let(:password) { 'foo' }

      it "calls #send_command with the password set in #initialize" do
        expect(subject).to receive(:send_command).with(:password, password).and_return(true)
        subject.authenticate
      end
    end

    context "without a password" do
      let(:password) { nil }

      it "does NOT call send_command" do
        expect(subject).to_not receive(:send_command)
        subject.authenticate
      end
    end
  end

  describe '#connect' do
    context "when already connected" do
      before do
        expect(subject).to receive(:connected?).and_return(true)
      end

      it 'raises an error' do
        expect { subject.connect }.to raise_error(MPD::ConnectionError)
      end
    end

    # context "when not yet connected" do
    #   before do
    #     expect(subject).to receive(:connected?).and_return(false)
    #   end

    #   it 'calls #authenticate' do
    #     expect(subject).to receive(:authenticate)
    #     subject.connect
    #   end
    # end
  end

  # describe '#socket' do
  #   let(:socket_file) { File.expand_path('../support/socket.sock',  __FILE__) }
  #   let(:socket) { subject.send(:socket) }

  #   context "if the hostname is a file that exists" do
  #     subject { MPD.new(socket_file) }

  #     before do
  #       allow(File).to receive(:exists?).with(socket_file).and_return(true)
  #       allow(UNIXSocket).to receive(:new).with(socket_file).and_return('unix socket stub')
  #     end

  #     it 'uses a Unix socket' do
  #       expect(socket).to eql('unix socket stub')
  #     end
  #   end

  #   context "if the hostname does NOT exist" do
  #     subject { MPD.new('localhost') }

  #     it 'uses a TCP socket' do
  #       expect(socket).to be_a(TCPSocket)
  #     end
  #   end
  # end
end
