require 'routemaster/jobs/client'
require 'routemaster/jobs/cache_and_sweep'

RSpec.describe Routemaster::Jobs::Client do
  let(:client) { Routemaster::Jobs::Client.new(adapter) }

  let(:perform) do
    client.enqueue('routemaster', Routemaster::Jobs::CacheAndSweep, 'https://example.com/1')
  end

  describe '#enqueue' do
    before do
      allow(Routemaster::Config).to receive(:queue_adapter).and_return(backend)
      allow(client).to receive(:enqueue).and_call_original
    end

     context 'when the backend is Resque' do
      let(:backend) { :resque }
      let(:adapter) { double('Resque', enqueue_to: nil) }

      it 'queues a Resque fetch job' do
        expect(adapter).to receive(:enqueue_to).with(
          'routemaster',
          Routemaster::Jobs::Backends::Resque::JobWrapper,
          { 'class' => 'Routemaster::Jobs::CacheAndSweep', 'args' => ['https://example.com/1'] })
        perform
      end
    end

    context 'when the backend is Sidekiq' do
      let(:backend) { :sidekiq }
      let(:adapter) { double('Sidekiq', push: nil) }

      it 'queues a Sidekiq fetch job' do
        expect(adapter).to receive(:push).with(
          'queue' => 'routemaster',
          'class' => Routemaster::Jobs::Backends::Sidekiq::JobWrapper,
          'args' => [{ 'class' => 'Routemaster::Jobs::CacheAndSweep', 'args' => ['https://example.com/1'] }])
        perform
      end
    end
  end
end



