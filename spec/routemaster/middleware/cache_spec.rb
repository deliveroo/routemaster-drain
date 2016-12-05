require 'spec_helper'
require 'spec/support/rack_test'
require 'routemaster/middleware/cache'

RSpec.describe Routemaster::Middleware::Cache do
  # busts the cache for each dirty url

  let(:terminator) { ErrorRackApp.new }
  let(:app) { described_class.new(terminator, **options) }
  let(:client) { Routemaster::Jobs::Client.new }
  let(:cache) { instance_double(Routemaster::Cache, bust: nil) }
  let(:options) {{ cache: cache, client: client }}

  let(:perform) do
    post '/whatever', '', 'routemaster.dirty' => payload
  end

  describe '#call' do
    let(:payload) { ['https://example.com/1'] }

    it 'busts the cache' do
      expect(cache).to receive(:bust).with(payload.first)
      perform
    end

    it 'queues a fetch job' do
      expect(client).to receive(:enqueue).with('routemaster', Routemaster::Jobs::CacheAndSweep, 'https://example.com/1')
      perform
    end
  end
end



