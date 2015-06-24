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

  describe "#on" do
    it 'should add a callback when passed as a block' do
      subject.on :volume do |volume|
        "Volume was set to #{volume}!"
      end

      cb = subject.instance_variable_get(:@callbacks)
      expect(cb[:volume].first.call(99)).to eql('Volume was set to 99!')
    end

    it "should add a callback when passed a proc" do
      method = Proc.new {|volume| "Volume was set to #{volume}!" }
      subject.on :volume, &method

      cb = subject.instance_variable_get(:@callbacks)
      expect(cb[:volume].first.call(99)).to eql('Volume was set to 99!')
    end

    it "should add multiple callbacks for the same event" do
      subject.on :volume do |volume|
        "First vol change #{volume}!"
      end

      subject.on :volume do |volume|
        "Last vol change #{volume}!"
      end

      cb = subject.instance_variable_get(:@callbacks)
      expect(cb[:volume].first.call(99)).to eql('First vol change 99!')
      expect(cb[:volume].last.call(77)).to eql('Last vol change 77!')
    end
  end

  describe "#emit" do
    x = 0

    it "should trigger callbacks" do
      subject.on :volume do |volume|
        x += volume
      end

      subject.on :volume do |volume|
        x += volume
      end

      subject.emit(:volume, 32)
      expect(x).to eql(64)
    end
  end

  describe '#connect' do
    context "when not yet connected" do
      before do
        expect(subject).to receive(:connected?).and_return(false)
        expect(subject).to receive(:socket).and_return(double(gets: "OK MPD 0.17.0\n"))
      end

      it 'calls #authenticate' do
        expect(subject).to receive(:authenticate)
        subject.connect
        expect(subject.instance_variable_get(:@version)).to eql('0.17.0')
      end
    end

    context "when possible too many connections" do
      let(:socket) { double('socket') }

      it {
        expect(subject).to receive(:socket).and_return(socket)
        expect(socket).to receive(:gets).and_return(nil)
        expect(subject).to receive(:reset_vars)
        expect(subject).to receive(:connected?).and_return(false)
        expect { subject.connect }.to raise_error(MPD::ConnectionError)
      }
    end

    context "when already connected" do
      before do
        expect(subject).to receive(:connected?).and_return(true)
      end

      it 'raises an error' do
        expect { subject.connect }.to raise_error(MPD::ConnectionError)
      end
    end
  end

  describe '#connect?' do
    context "when there is no socket" do
      it {
        subject.instance_variable_set(:@socket, nil)
        expect(subject.connected?).to be_falsey
      }
    end

    context "when there is a socket but pinging fails" do
      it {
        subject.instance_variable_set(:@socket, true)
        expect(subject).to receive(:send_command).with(:ping).and_raise("Bang!")
        expect(subject.connected?).to be_falsey
      }
    end

    context "when there is a socket and pinging is successful" do
      it {
        subject.instance_variable_set(:@socket, true)
        expect(subject).to receive(:send_command).with(:ping).and_return(true)
        expect(subject.connected?).to be_truthy
      }
    end
  end

  describe '#disconnect' do
    context "when there is no socket" do
      it {
        subject.instance_variable_set(:@socket, false)
        expect(subject).not_to receive(:reset_vars)
        expect(subject.disconnect).to be_falsey
      }
    end

    context "when Errno::EPIPE is raised" do
      let(:socket) { double(puts: true, close: true) }

      it {
        subject.instance_variable_set(:@socket, socket)
        expect(socket).to receive(:puts).and_raise(Errno::EPIPE)
        expect(socket).not_to receive(:close)
        expect(subject).to receive(:reset_vars)
        expect(subject.disconnect).to be_truthy
      }
    end

    context "when there is a socket" do
      let(:socket) { double(puts: true, close: true) }

      it {
        subject.instance_variable_set(:@socket, socket)
        expect(socket).to receive(:puts).with('close')
        expect(socket).to receive(:close)
        expect(subject).to receive(:reset_vars)
        expect(subject.disconnect).to be_truthy
      }
    end
  end

  describe '#reconnect' do
    it {
      expect(subject).to receive(:disconnect)
      expect(subject).to receive(:connect).and_return(true)
      expect(subject.reconnect).to be_truthy
    }
  end

  describe '#kill' do
    it {
      expect(subject).to receive(:send_command).with(:kill)
      subject.kill
    }
  end

  describe '#password=' do
    let(:password) { 'password' }

    it {
      expect(subject).to receive(:send_command).with(:password, password)
      subject.password(password)
    }
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

  describe '#ping' do
    it {
      expect(subject).to receive(:send_command).with(:ping)
      subject.ping
    }
  end

  describe '#send_command' do
    context "when we have no socket" do
      it {
        subject.instance_variable_set(:@socket, false)
        expect(subject).not_to receive(:handle_server_response)
        expect(subject).not_to receive(:parse_response)
        expect { subject.send_command(:do_something) }.to raise_error(MPD::ConnectionError)
      }
    end

    context "when we set the volume" do
      let(:socket) { double('socket').as_null_object }
      let(:response) { "VOLUME: 11\n" }
      let(:ok) { "OK\n" }

      before :each do
        subject.instance_variable_set(:@socket, socket)
        expect(socket).to receive(:puts).with('setvol 11')
        expect(socket).to receive(:gets).and_return(response)
        expect(socket).to receive(:gets).and_return(ok)
      end

      it {
        expect(subject.send_command(:setvol, 11)).to eql(11)
      }
    end

    context "when we have a pipe error when sending command" do
      let(:socket) { double('socket').as_null_object }
      let(:response) { "VOLUME: 11\n" }
      let(:ok) { "OK\n" }

      before :each do
        subject.instance_variable_set(:@socket, socket)
        expect(subject).to receive(:reconnect).once
        expect(socket).to receive(:puts).and_raise(Errno::EPIPE)
        expect(socket).to receive(:puts).with('setvol 11')
        expect(socket).to receive(:gets).and_return(response)
        expect(socket).to receive(:gets).and_return(ok)
      end

      it {
        expect(subject.send_command(:setvol, 11)).to eql(11)
      }
    end
  end

  describe "#start_callback_thread!" do
    let(:processor) { double('processor') }

    it "should do a loop" do
      allow(MPD::CallbackProcessor).to receive(:new).and_return(processor)
      expect(Thread).to receive(:new).and_yield
      expect(subject).to receive(:loop).and_yield
      expect(processor).to receive(:process!).once
      subject.send(:start_callback_thread!)
    end
  end

  describe "#handle_server_response" do
    let(:socket) { double('socket').as_null_object }

    before :each do
      subject.instance_variable_set(:@socket, socket)
    end

    context "when we get a correct response" do
      let(:response) { "VOLUME: 11\n" }
      let(:response2) { "XFADE: 12\n" }
      let(:ok) { "OK\n" }

      it {
        expect(socket).to receive(:gets).and_return(response)
        expect(socket).to receive(:gets).and_return(response2)
        expect(socket).to receive(:gets).and_return(ok)
        expect(subject.send(:handle_server_response)).to eql("VOLUME: 11\nXFADE: 12\n")
      }
    end

    context "when we get an error response" do
      let(:response) { "VOLUME: 11\n" }
      let(:response2) { "XFADE: 12\n" }
      let(:bang) { "ACK [52@0] {volume} problems setting volume\n" }

      it {
        expect(socket).to receive(:gets).and_return(response)
        expect(socket).to receive(:gets).and_return(response2)
        expect(socket).to receive(:gets).and_return(bang)
        expect { subject.send(:handle_server_response) }
          .to raise_error(MPD::SystemError, "[volume] problems setting volume")
      }
    end
  end

  describe "#socket" do
    it {
      expect(TCPSocket).to receive(:new)
      subject.send(:socket)
    }
  end

  describe "SERVER_ERROR codes" do
    it {
      [1,2,3,4,5,50,51,52,53,54,55,56].each do |code|
        expect(subject.class::SERVER_ERRORS.keys).to include(code)
      end
    }
  end
end
