require 'spec_helper'
require_relative '../../lib/ruby-mpd/exceptions'

RSpec.describe "Exceptions" do
  it { expect(MPD::Error.superclass).to eql(StandardError) }
  it { expect(MPD::ConnectionError.superclass).to eql(MPD::Error) }
  it { expect(MPD::ServerError.superclass).to eql(MPD::Error) }
  it { expect(MPD::NotListError.superclass).to eql(MPD::ServerError) }
  it { expect(MPD::ServerArgumentError.superclass).to eql(MPD::ServerError) }
  it { expect(MPD::IncorrectPassword.superclass).to eql(MPD::ServerError) }
  it { expect(MPD::PermissionError.superclass).to eql(MPD::ServerError) }
  it { expect(MPD::NotFound.superclass).to eql(MPD::ServerError) }
  it { expect(MPD::PlaylistMaxError.superclass).to eql(MPD::ServerError) }
  it { expect(MPD::SystemError.superclass).to eql(MPD::ServerError) }
  it { expect(MPD::PlaylistLoadError.superclass).to eql(MPD::ServerError) }
  it { expect(MPD::AlreadyUpdating.superclass).to eql(MPD::ServerError) }
  it { expect(MPD::NotPlaying.superclass).to eql(MPD::ServerError) }
  it { expect(MPD::AlreadyExists.superclass).to eql(MPD::ServerError) }
end
