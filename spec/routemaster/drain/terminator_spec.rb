require 'spec_helper'
require 'spec/support/rack_test'
require 'spec/support/events'
require 'routemaster/drain/terminator'

describe Routemaster::Drain::Terminator do
  let(:app) { described_class.new }
  let(:listener) { double }

  let(:perform) do
    post '/whatever', '', 'routemaster.payload' => payload
  end

  before do
    app.subscribe(listener, prefix: true)
  end
  

  context 'when a payload is present' do
    let(:payload) { [double('event')] } 

    it 'responds 204' do
      perform
      expect(last_response.status).to eq(204)
    end

    it 'broadcasts :events_received' do
      expect(listener).to receive(:on_events_received).with(payload)
      perform
    end
  end

  context 'when a payload is present but empty' do
    let(:payload) { [] } 

    it 'responds 204' do
      perform
      expect(last_response.status).to eq(204)
    end

    it 'does not broadcast :events_received' do
      expect(listener).not_to receive(:on_events_received)
      perform
    end
  end

  context 'when there is no payload' do
    let(:payload) { nil } 

    it 'responds 400' do
      perform
      expect(last_response.status).to eq(400)
    end

    it 'does not broadcast' do
      expect(listener).not_to receive(:on_events_received)
      perform
    end
  end
end

