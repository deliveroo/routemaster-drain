require 'spec_helper'
require 'spec/support/rack_test'
require 'spec/support/uses_redis'
require 'spec/support/uses_dotenv'
require 'spec/support/events'
require 'spec/support/siphon'
require 'routemaster/drain/mapping'
require 'json'

describe Routemaster::Drain::Mapping do
  uses_dotenv
  uses_redis

  let(:app) { described_class.new(options) }
  let(:options) { {} }
  let(:listener) { double 'listener' }

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

  it 'filters events' do
    expect(listener).to receive(:on_events_received) do |payload|
      expect(payload.size).to eq(3) # the second 1 is filtered
    end
    perform
  end

  let(:map) { Routemaster::Dirty::Map.new }

  it 'uses dirty map' do
    payload1 = [1,2,3,1].map { |idx| make_event(idx) }.to_json
    payload2 = [1,4,5,2].map { |idx| make_event(idx) }.to_json

    post path, payload1, environment
    expect(map.count).to eq(3)
    map.sweep_one("https://example.com/stuff/1") { true }

    post path, payload2, environment
    expect(map.count).to eq(4) # 2, 3, 4, 5 (1 is a repeat event, filtered out)
  end
end
