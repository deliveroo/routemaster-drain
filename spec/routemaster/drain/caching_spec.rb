require 'spec_helper'
require 'spec/support/rack_test'
require 'spec/support/uses_redis'
require 'spec/support/uses_dotenv'
require 'spec/support/events'
require 'routemaster/drain/caching'
require 'json'

describe Routemaster::Drain::Caching do
  uses_dotenv
  uses_redis

  let(:app) { described_class.new }
  let(:listener) { double 'listener' }

  before { app.subscribe(listener, prefix: true) }

  let(:path)    { '/' }
  let(:payload) { [1,2,3,1].map { |idx| make_event(idx) }.to_json }
  let(:environment) {{ 'CONTENT_TYPE' => 'application/json' }}
  let(:perform) { post path, payload, environment }

  before { authorize 'd3m0', 'x' }

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

  it 'busts the cache' do
    expect_any_instance_of(Routemaster::Cache).to receive(:bust).exactly(3).times
    perform
  end

  it 'schedules caching jobs' do
    expect_any_instance_of(Routemaster::Jobs::Client).to receive(:enqueue).exactly(3).times
    perform
  end
end

