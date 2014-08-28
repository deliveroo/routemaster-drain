require 'spec_helper'
require 'spec/support/rack_test'
require 'routemaster/middleware/cache'

describe Routemaster::Middleware::Cache do
 
  # busts the cache for each dirty url

  let(:terminator) { ErrorRackApp.new }
  let(:app) { described_class.new(terminator, **options) }
  let(:resque) { double 'resque', enqueue_to: nil }
  let(:cache) { double 'cache', bust: nil }
  let(:options) {{ cache: cache, resque: resque }}
  
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
      expect(resque).to receive(:enqueue_to).with('routemaster', anything, 'https://example.com/1')
      perform
    end
  end
end



