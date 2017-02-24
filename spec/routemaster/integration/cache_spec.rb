require 'spec_helper'
require 'spec/support/uses_redis'
require 'spec/support/uses_dotenv'
require 'spec/support/server'
require 'routemaster/cache'
require 'webrick'

RSpec.describe 'Requests with caching' do
  uses_dotenv
  uses_redis

  let!(:log) { WEBrick::Log.new '/dev/null' }
  let(:service) do
    TestServer.new(8000) do |server|
      server.mount_proc '/test' do |req, res|
        res.body = { field: 'test' }.to_json
      end
    end
  end

  before { service.start }
  after { service.stop }

  subject { Routemaster::Cache.new }

  describe 'GET request' do
    let(:body_cache_keys) { ["cache:#{url}", "v:,l:,body"] }
    let(:headers_cache_keys) { ["cache:#{url}", "v:,l:,headers"] }
    let(:url) { 'http://localhost:8000/test' }

    context 'when there is no previous cached response' do
      it 'makes an http call' do
        response = subject.get(url)
        expect(response.headers['server']).to be
      end

      it 'sets the new response onto the cache' do
        expect { subject.get(url) }
          .to change { Routemaster::Config.cache_redis.hget(*body_cache_keys)}
          .from(nil)
          .to({ field: 'test'}.to_json)
      end

      it 'sets the response headers onto the cache' do
        expect { subject.get(url) }
          .to change { Routemaster::Config.cache_redis.hget(*headers_cache_keys)}
          .from(nil)
      end
    end

    context 'when there is a previous cached response' do
      before { subject.get(url) }

      it 'fetches the cached response' do
        expect(subject.get(url).body).to eq({ field: 'test' }.to_json)
      end

      it 'does not make an http call' do
        response = subject.get(url)
        expect(response.env.request).to be_empty
      end
    end
  end
end
