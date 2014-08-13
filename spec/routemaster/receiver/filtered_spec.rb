require 'spec_helper'
require 'spec/support/rack_test'
require 'routemaster/receiver/filtered'
require 'spec/support/write_expectation'
require 'spec/support/uses_redis'

describe Routemaster::Receiver::Filtered do
  uses_redis

  def perform
    post '/events', payload, 
      'CONTENT_TYPE' => 'application/json',
      'routemaster.authenticated' => true
  end

  def message(idx, t = 1)
    { topic: 'widgets', type: 'create', url: "https://example.com/widgets/#{idx}", t: t }
  end
  
  let(:payload) {
    [
      message(1), message(2), message(3), message(1)
    ].to_json
  }

  let(:handler) { double 'handler' }
  let(:map) { Routemaster::Dirty::Map.new(redis) }
  
  let(:options) {{
    path:       '/events',
    uuid:       'demo',
    redis:      redis,
    dirty_map:  map
  }}

  let(:app) { described_class.new(ErrorRackApp.new, options) }

  it 'delegates to the next middleware for unknown paths' do
    post '/foobar'
    expect(last_response.status).to eq(501)
  end

  it 'delegates to the next middlex for non-POST' do
    get '/events'
    expect(last_response.status).to eq(501)
  end

  context 'with a listener' do
    let(:handler) { double }
    before { Wisper.add_listener(handler, scope: described_class.name, prefix: true) }
    after { Wisper::GlobalListeners.instance.clear }
    before { authorize 'demo', 'x' }

    it 'broadcasts :sweep_needed' do
      # emit event once per entity
      expect(handler).to receive(:on_sweep_needed).exactly(3).times
      perform
    end

    it 'does not rebroadcast duplicates' do
      perform
      expect(handler).not_to receive(:on_sweep_needed)
      perform
    end

    it 'broadcasts once per entity' do
      payload.replace([message(1, 1234), message(1, 1235)].to_json)
      expect(handler).to receive(:on_sweep_needed).exactly(:once)
      perform
    end

    it 'makes map sweepable' do
      payload.replace([message(1)].to_json)
      perform
      expect { |b| map.sweep(&b) }.to yield_with_args('https://example.com/widgets/1')
    end
  end
end
