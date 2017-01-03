require 'spec_helper'
require 'spec/support/uses_redis'
require 'spec/support/uses_dotenv'
require 'spec/support/uses_webmock'
require 'routemaster/cache'
require 'routemaster/api_client'

module Routemaster
  describe Cache do
    uses_dotenv
    uses_redis
    uses_webmock

    let(:url) { 'https://www.example.com/widgets/123' }

    before do
      stub_request(:get, /example\.com/).to_return(
        status:   200,
        body:     { id: 123, type: 'widget' }.to_json,
        headers:  {
          'content-type' => 'application/json;v=1'
        }
      )
    end

    shared_examples 'a GET request' do
      context 'with no options' do
        let(:options) { {} }

        it 'calls get on the api client with no version and locale headers' do
          expect_any_instance_of(APIClient)
            .to receive(:get)
            .with(url, headers: { 'Accept' => 'application/json' })
            .and_call_original

          perform.status
        end
      end

      context 'with a specific version' do
        let(:options) { { version: 2 } }

        it 'calls get on the api client with version header' do
          expect_any_instance_of(APIClient)
            .to receive(:get)
            .with(url, headers: { 'Accept' => 'application/json;v=2' })
            .and_call_original

          perform.status
        end
      end

      context 'with a specific locale' do
        let(:options) { { locale: 'fr' } }

        it 'calls get on the api client with locale header' do
          expect_any_instance_of(APIClient)
            .to receive(:get)
            .with(url, headers: { 'Accept' => 'application/json', 'Accept-Language' => 'fr' })
            .and_call_original

          perform.status
        end
      end
    end

    describe '#get' do
      let(:perform) { subject.get(url, **options) }

      it_behaves_like 'a GET request'
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
