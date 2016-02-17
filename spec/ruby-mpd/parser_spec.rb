require 'spec_helper'
require_relative '../../lib/ruby-mpd'

RSpec.describe MPD::Parser do
  subject { MPD.new }

  describe "#convert_command" do
    context "when given boolean params of true" do
      let(:args) { [:convert_command, 'command', true] }
      it { expect(subject.send(*args)).to eql("command 1") }
    end

    context "when given boolean params of false" do
      let(:args) { [:convert_command, 'command', false] }
      it { expect(subject.send(*args)).to eql("command 0") }
    end

    context "when given params that are a range" do
      let(:args) { [:convert_command, 'command', 1...3] }
      it { expect(subject.send(*args)).to eql("command 1:3") }
    end

    context "when given params that are a inclusive range" do
      let(:args) { [:convert_command, 'command', 1..3] }
      it { expect(subject.send(*args)).to eql("command 1:4") }
    end

    context "when given params that are a range with -1" do
      let(:args) { [:convert_command, 'command', 2..-1] }
      it { expect(subject.send(*args)).to eql("command 2:") }
    end

    context "when given a MPD::Song" do
      let(:song) { MPD::Song.new('mpd', {}) }
      let(:args) { [:convert_command, 'command', song] }

      it {
        allow(song).to receive(:file).and_return('filename123')
        expect(subject.send(*args)).to eql("command filename123")
      }

      it {
        allow(song).to receive(:file).and_return('filename "123"')
        expect(subject.send(*args)).to eql('command "filename \"123\""')
      }
    end

    context "when given params with a backslash" do
      let(:args) { [:convert_command, 'command', "a\\b"] }
      it { expect(subject.send(*args)).to eql('command "a\\\\b"') }
    end

    context "when given params that are a hash" do
      let(:args) { [:convert_command, 'command', {foo:'foo', bar:'bar baz', quux:'"xyzzy"', escape:"a\\b"}] }
      it { expect(subject.send(*args)).to eql('command foo foo bar "bar baz" quux "\"xyzzy\"" escape "a\\\\b"') }
    end

    context "when given params of a string" do
      let(:args) { [:convert_command, 'command', 'a string'] }
      it { expect(subject.send(*args)).to eql("command \"a string\"") }
    end

    context "when given params of an integer" do
      let(:args) { [:convert_command, 'command', 32] }
      it { expect(subject.send(*args)).to eql("command 32") }
    end
  end

  describe "#parse_key" do
    context "with valid INT_KEYS" do
      MPD::Parser::INT_KEYS.each do |key|
        it { expect(subject.send(:parse_key, key, '32')).to eql(32) }
      end
    end

    context "with valid SYM_KEYS" do
      MPD::Parser::SYM_KEYS.each do |key|
        it { expect(subject.send(:parse_key, key, 'value')).to eql(:value) }
      end
    end

    context "with valid FLOAT_KEYS" do
      MPD::Parser::FLOAT_KEYS.each do |key|
        it { expect(subject.send(:parse_key, key, 10)).to eql(10.0) }
        it { expect(subject.send(:parse_key, key, 'nan')).to be(Float::NAN) }
      end
    end

    context "with valid BOOL_KEYS" do
      MPD::Parser::BOOL_KEYS.each do |key|
        it { expect(subject.send(:parse_key, key, '1')).to be_truthy }
        it { expect(subject.send(:parse_key, key, '0')).to be_falsey }
      end
    end

    context "with :playlist key" do
      it { expect(subject.send(:parse_key, :playlist, '32')).to eql(32) }
      it { expect(subject.send(:parse_key, :playlist, '0')).to eql('0') }
    end

    context "with :db_update key" do
      expected_time = Time.at(1434024873)
      it { expect(subject.send(:parse_key, :db_update, '1434024873').utc)
        .to eql(expected_time.utc) }
    end

    context "with :'last-modified' key" do
      let(:time) { Time.parse("Thu Nov 29 14:33:20 GMT 2001") }
      it { expect(subject.send(:parse_key, :"last-modified", time.utc.iso8601))
        .to eql(time) }
    end

    context "with :time, :audio key" do
      it { expect(subject.send(:parse_key, :time, '123')).to eql([nil, 123]) }
      it { expect(subject.send(:parse_key, :time, '99:123')).to eql([99, 123]) }
      it { expect(subject.send(:parse_key, :audio, '12:33')).to eql([12, 33]) }
    end
  end

  describe "#parse_line" do
    context "with a valid response line" do
      let(:response) { "UPTIME:32\n xxxx" }
      it { expect(subject.send(:parse_line, response)).to eql([:uptime, 32]) }
    end
  end

  describe "#build_songs_list" do
    context "when passed an empty array" do
      it { expect(subject.send(:build_songs_list, [])).to eql([]) }
    end
  end

  describe "#parse_response" do
    context "when passed listall command" do
      let(:command) { :listall }
      let(:str) { "File: file1\nFile: file2\nFile: file3\nFile: file4\n" }
      it { expect(subject.send(:parse_response, command, str))
        .to eql({:file=>["file1", "file2", "file3", "file4"]}) }
    end

    context "when passed listallinfo command" do
      let(:command) { :listallinfo }
      let(:str) { "Directory: xxxx\nFile: file1\nFile: file2\nFile: file3\nFile: file4\n" }
      it { expect(subject.send(:parse_response, command, str))
        .to eql(["file1", "file2", "file3", "file4"]) }
    end

    context "when passed unknown command with empty string" do
      let(:command) { :xxxx }
      let(:str) { "" }
      it { expect(subject.send(:parse_response, command, str)).to eql(true) }
    end

    context "when passed known command with data" do
      let(:command) { :outputs }
      let(:str) { "" }
      it { expect(subject.send(:parse_response, command, str)).to be_empty }
    end

    context "when passed valid command and a string of elements" do
      let(:command) { :find }
      let(:str) { "title: Shelter\nTrack: 7\nxfade: 0\nstate: play\n" }
      it { expect(subject.send(:parse_response, command, str))
        .to eql([{:title=>"Shelter", :track=>7, :xfade=>0, :state=>:play}]) }
    end

    context "when passed valid command and a single element" do
      let(:command) { :find }
      let(:str) { "title: Shelter\n" }
      it { expect(subject.send(:parse_response, command, str)).to eql(["Shelter"]) }
    end

    context "when passed invalid command and a single element" do
      let(:command) { :xxxx }
      let(:str) { "title: Shelter\n" }
      it { expect(subject.send(:parse_response, command, str)).to eql("Shelter") }
    end
  end
end
