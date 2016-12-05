require 'spec_helper'
require 'spec/support/uses_redis'
require 'spec/support/uses_dotenv'
require 'faraday'
require 'routemaster/faraday_middleware/caching'
require 'routemaster/cache'

describe Routemaster::FaradayMiddleware::Caching do
  uses_dotenv
  uses_redis

  let(:body) {
    i = 0
    -> {
      i += 1
      "body #{i}"
    }
  }

  let(:stubs) do
    Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get('/test') { |env| [200, {}, body.call] }
    end
  end

  let(:faraday_client) {
    Faraday.new 'http://www.example.com' do |conn|
      conn.use Routemaster::FaradayMiddleware::Caching
      conn.adapter :test, stubs
    end
  }

  it 'returns a faraday response object' do
    expect(faraday_client.get('/test')).to be_a Faraday::Response
  end

  it 'will fetch from the cache for multiple requests to the same endpoint' do
    expect(faraday_client.get('/test').body).to eq "body 1"
    expect(faraday_client.get('/test').body).to eq "body 1"
  end

  it 'will not fetch from the cache for a request with different Accept or Accept-Language headers' do
      en_v1_1 = faraday_client.get('/test') do |req|
        req.headers['Accept'] = "application/json;v=1"
        req.headers['Accept-Language'] = "en"
      end

      en_v1_2 = faraday_client.get('/test') do |req|
        req.headers['Accept'] = "application/json;v=1"
        req.headers['Accept-Language'] = "en"
      end

      en_2 = faraday_client.get('/test') do |req|
        req.headers['Accept'] = "application/json;v=2"
        req.headers['Accept-Language'] = "en"
      end

      fr_1 = faraday_client.get('/test') do |req|
        req.headers['Accept'] = "application/json;v=1"
        req.headers['Accept-Language'] = "fr"
      end

      expect(en_v1_1.body).to eq "body 1"
      expect(en_v1_2.body).to eq "body 1"
      expect(en_2.body).to eq "body 2"
      expect(fr_1.body).to eq "body 3"
  end

  it 'will cache requests in the same format as Routemaster::Cache' do
      faraday_resp = faraday_client.get('/test') do |req|
        req.headers['Accept'] = "application/json;v=1"
        req.headers['Accept-Language'] = "en"
      end
      cache_resp = Routemaster::Cache.new.get("http://www.example.com/test", version: 1, locale: 'en')

      expect(faraday_resp.body).to eq "body 1"
      expect(cache_resp.body).to eq "body 1"

      fetcher = double
      expect(fetcher).to receive(:get) do
        Hashie::Mash.new(status: 200, headers: {}, body: body.call)
      end

      cache_resp = Routemaster::Cache.new(fetcher: fetcher).get("http://www.example.com/test", version: 2, locale: 'en')
      faraday_resp = faraday_client.get('/test') do |req|
        req.headers['Accept'] = "application/json;v=2"
        req.headers['Accept-Language'] = "en"
      end

      expect(faraday_resp.body).to eq "body 2"
      expect(cache_resp.body).to eq "body 2"
  end
end
