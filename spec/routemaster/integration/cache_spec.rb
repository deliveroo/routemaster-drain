require 'spec_helper'
require 'spec/support/uses_redis'
require 'spec/support/uses_dotenv'
require 'spec/support/uses_webmock'
require 'spec/support/server'
require 'routemaster/cache'
require 'webrick'

describe Routemaster::Cache do
  uses_dotenv
  uses_redis
  uses_webmock

  def time_us
    Integer(Time.now.to_f * 1e6)
  end

  let(:service) do
    TestServer.new(8000) do |server|
      server.mount_proc '/test' do |req, res|
        res['content-type'] = 'application/json'
        res['x-timestamp'] = time_us.to_s
        res.body = { value: time_us }.to_json
      end
    end
  end

  before { service.start }
  after { service.stop }

  before { WebMock.disable_net_connect!(allow_localhost: true) }


  shared_examples 'a cached GET' do
    let(:url) { 'http://localhost:8000/test' }

    let(:response) { perform.call }

    context 'when there is no previous cached response' do
      it 'makes a HTTP request' do
        perform.call
        expect(WebMock).to have_requested(:get, 'http://localhost:8000/test')
      end

      it 'returns fresh headers' do
        time_before = time_us()
        expect(response.headers['x-timestamp'].to_i).to be > time_before
      end

      it 'returns a fresh body' do
        time_before = time_us()
        expect(response.body.value).to be > time_before
      end
    end

    context 'when there is a cached response' do
      before { perform.call }

      it 'returns cached headers' do
        time_before = time_us()
        expect(response.headers['x-timestamp'].to_i).to be < time_before
      end

      it 'returns a cached body' do
        time_before = time_us()
        expect(response.body.value).to be < time_before
      end

      it 'makes no HTTP requests' do
        WebMock.reset!
        perform.call
        expect(WebMock).not_to have_requested(:any, //)
      end
    end
  end


  describe '#get' do
    let(:perform) { -> { subject.get(url) } }
    it_behaves_like 'a cached GET'
  end

  describe '#fget' do
    let(:perform) { -> { subject.fget(url).value } }
    it_behaves_like 'a cached GET'
  end
end
