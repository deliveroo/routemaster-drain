require 'spec_helper'
require 'spec/support/rack_test'
require 'spec/support/uses_redis'
require 'spec/support/uses_dotenv'
require 'spec/support/events'
require 'spec/support/siphon'

require 'routemaster/drain/cache_busting'
require 'json'

describe Routemaster::Drain::CacheBusting do
  uses_dotenv
  uses_redis

  let(:app) { described_class.new options }
  let(:listener) { double 'listener' }
  let(:options) { {} }

  before { app.subscribe(listener, prefix: true) }

  let(:path)    { '/' }
  let(:payload) { [1,2,3,1].map { |idx| make_event(idx) } }
  let(:environment) {{ 'CONTENT_TYPE' => 'application/json' }}
  let(:perform) { post path, payload.to_json, environment }

  before { authorize 'd3m0', 'x' }

  include_examples 'supports siphon'

  it 'succeeds' do
    perform
    expect(last_response.status).to eq(204)
  end

  it 'emits events' do
    expect(listener).to receive(:on_events_received) do |payload|
      expect(payload.size).to eq(3)
    end
    perform
  end

  it 'increments the event index' do
    ei_double = double(increment: 1)
    allow(Routemaster::EventIndex).to receive(:new).and_return(ei_double)
    expect(ei_double).to receive(:increment).exactly(3).times
    perform
  end
end
