require 'spec_helper'
require 'spec/support/rack_test'
require 'spec/support/events'
require 'routemaster/middleware/dirty'

describe Routemaster::Middleware::Dirty do
  let(:terminator) { ErrorRackApp.new }
  let(:app) { described_class.new(terminator, options) }

  def perform(payload = nil)
    post '/whatever', '', 'routemaster.payload' => payload
  end

  describe '#call' do
    let(:map) { double 'dirty_map' }
    let(:options) {{ dirty_map: map }}
    let(:handler) { double }

    it 'marks the dirty map on events' do
      expect(map).to receive(:mark).exactly(:twice)
      perform([make_event(1), make_event(2)])
    end

    it 'stores dirty URLs in the environment' do
      allow(map).to receive(:mark).and_return(true, false)
      perform([make_event(1), make_event(1)])
      expect(terminator.last_env['routemaster.dirty']).to eq(['https://example.com/stuff/1'])
    end

    it 'increments the event_index' do
      allow(map).to receive(:mark).and_return(true, false)
      ei_double = double(increment: 1)
      expect(Routemaster::EventIndex).to receive(:new).twice.and_return(ei_double)
      expect(ei_double).to receive(:increment)
      perform([make_event(1), make_event(1)])
    end
  end
end
