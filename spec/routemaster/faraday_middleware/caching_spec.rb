require 'spec_helper'
require 'faraday'
require 'routemaster/faraday_middleware/caching'

describe Routemaster::FaradayMiddleware::Caching do

  let(:cache) { double.as_null_object }
  let(:app) { double.as_null_object }

  let(:faraday_client) {
    Faraday.new 'http://www.example.com' do |conn|
      conn.use Routemaster::FaradayMiddleware::Caching, cache
    end
  }

  context 'With supplied Accept and Accept-Language headers' do
    it 'parses url, version and locale from the request headers and passes \
    them to cache#fetch' do
      expect(cache).to receive(:fetch).with('http://www.example.com/anything', version: '1', locale: 'en').and_yield
      expect_any_instance_of(described_class).to receive(:app) { app }
      expect(app).to receive(:call)

      faraday_client.get('/anything') do |req|
        req.headers['Accept'] = "application/json;v=1"
        req.headers['Accept-Language'] = "en"
      end
    end
  end

  context 'Without Accept and Accept-Language headers' do
    it 'only calles cache#with_caching with the url' do
      expect(cache).to receive(:fetch).with('http://www.example.com/anything').and_yield
      expect_any_instance_of(described_class).to receive(:app) { app }
      expect(app).to receive(:call)

      faraday_client.get('/anything')
    end
  end
end
