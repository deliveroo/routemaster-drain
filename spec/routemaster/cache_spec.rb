require 'spec_helper'
require 'spec/support/uses_redis'
require 'spec/support/uses_dotenv'
require 'routemaster/cache'
require 'routemaster/fetcher'

module Routemaster
  describe Cache do
    uses_dotenv
    uses_redis

    let(:url) { 'https://www.example.org/widgets/123' }

    subject { described_class.new }

    describe '#get' do
      let(:perform) { subject.get(url, **options) }

      context 'with no options' do
        let(:perform) { subject.get(url) }

        it 'calls get on the fetcher with no version and locale headers' do
          expect_any_instance_of(Fetcher)
            .to receive(:get)
            .with(url, headers: { 'Accept' => 'application/json' })

          perform
        end
      end

      context 'with a specific version' do
        let(:options) { { version: 2 } }

        it 'calls get on the fetcher with version header' do
          expect_any_instance_of(Fetcher)
            .to receive(:get)
            .with(url, headers: { 'Accept' => 'application/json;v=2' })

          perform
        end
      end

      context 'with a specific locale' do
        let(:options) { { locale: 'fr' } }

        it 'calls get on the fetcher with locale header' do
          expect_any_instance_of(Fetcher)
            .to receive(:get)
            .with(url, headers: { 'Accept' => 'application/json', 'Accept-Language' => 'fr' })

          perform
        end
      end
    end

    describe '#fget' do
      let(:options) { {} }
      let(:perform) { subject.fget(url, **options) }

      context 'with no information needed' do
        it 'does not perform a GET request until we ask for information' do
          expect_any_instance_of(Fetcher)
            .not_to receive(:get)

          perform
        end


        it 'returns a FutureResponse' do
          expect(perform).to be_an_instance_of(Cache::FutureResponse)
        end
      end

      context 'with information about body, status or headers needed' do
        %w(status headers body).each do |info|
          it 'performs the actual GET request to fetch the information needed' do
            expect_any_instance_of(Fetcher)
              .to receive(:get)
              .with(url, anything)
              .and_return(double('FaradayResponse', info.to_sym => nil))

            perform.public_send(info.to_sym)
          end
        end
      end
    end

    describe '#bust' do
      let(:cache)   { Config.cache_redis }
      let(:perform) { subject.bust(url) }

      before do
        cache.set("cache:#{url}", "cached response")
      end

      it 'busts the cache for a given URL' do
        expect { perform }
          .to change { cache.get("cache:#{url}") }
          .from('cached response')
          .to(nil)
      end

      it 'publishes the cache_bust event for that URL' do
        expect_any_instance_of(described_class)
          .to receive(:publish)
          .with(:cache_bust, url)

        perform
      end
    end
  end
end
