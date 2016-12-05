require 'spec_helper'
require 'spec/support/uses_redis'
require 'spec/support/uses_dotenv'
require 'routemaster/cache'
require 'routemaster/fetcher'

module Routemaster
  describe Cache do
    uses_dotenv
    uses_redis

    let(:fetcher) { Fetcher.new(listener: listener) }
    let(:url) { 'https://example.com/widgets/132' }
    let(:cache) { Config.cache_redis }
    let(:listener) { double('listener', publish: nil) }
    subject { described_class.new(fetcher: fetcher) }

    before do
      allow(Config).to receive(:cache_auth).and_return('example.com' => ['test', 'test'])
      @conn = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.get(url) { |env| [ 200, {}, { id: 132, type: 'widget'}] }
        end
      end

      allow(fetcher).to receive(:connection).and_return(@conn)
    end

    shared_examples 'a response getter' do
      it 'fetches the url' do
        expect(fetcher).to receive(:get).with(url, anything)
        performer.call(url).status
      end

      it 'passes the locale header' do
        expect(fetcher).to receive(:get) do |url, **options|
          expect(options[:headers]['Accept-Language']).to eq('fr')
        end.and_call_original
        performer.call(url, locale: 'fr').status
      end

      it 'passes the version header' do
        expect(fetcher).to receive(:get) do |url, **options|
          expect(options[:headers]['Accept']).to eq('application/json;v=33')
        end
        performer.call(url, version: 33).status
      end

      it 'uses the cache' do
        expect(@conn).to receive(:get).once
        3.times { performer.call(url).status }
      end

      context 'with a listener' do
        before { subject.subscribe(listener) }

        it 'emits :cache_miss' do
          expect(listener).to receive(:cache_miss)
          performer.call(url).status
        end

        it 'misses on different locale' do
          expect(listener).to receive(:cache_miss).twice
          performer.call(url, locale: 'en').status
          performer.call(url, locale: 'fr').status
        end

        it 'emits :cache_miss' do
          allow(listener).to receive(:cache_miss)
          performer.call(url).status
          expect(listener).to receive(:cache_hit)
          performer.call(url).status
        end
      end
    end


    describe '#get' do
      let(:performer) { subject.method(:get) }

      it_behaves_like 'a response getter'
    end


    describe '#fget' do
      let(:performer) { subject.method(:fget) }

      it_behaves_like 'a response getter'
    end


    describe '#bust' do
      it 'causes next get to query' do
        expect(@conn).to receive(:get).twice
        subject.get(url)
        subject.bust(url)
        subject.get(url)
      end

      it 'emits :cache_bust' do
        subject.subscribe(listener, prefix: true)
        expect(listener).to receive(:on_cache_bust).once
        subject.bust(url)
      end
    end
  end
end
