require 'spec_helper'
require 'spec/support/uses_redis'
require 'spec/support/uses_dotenv'
require 'routemaster/cache'
require 'webrick'

RSpec.describe 'Requests with caching' do
  uses_dotenv
  uses_redis

  let(:service) do
    WEBrick::HTTPServer.new(:Port => 8000, :DocumentRoot => Dir.pwd).tap do |server|
      server.mount_proc '/test' do |req, res|
        res.body = { field: 'test' }.to_json
      end
    end
  end

  before do
    @pid = fork do
      trap 'INT' do service.shutdown end
      service.start
    end
    sleep(1) # leave sometime for the previous webrick to teardown
    Process.detach(@pid)
  end

  after do
    Process.kill('INT', @pid)
    sleep(1) # leave sometime for the previous webrick to teardown
  end

  subject { Routemaster::Cache.new }

  describe 'GET request' do
    let(:url) { 'http://localhost:8000/test' }

    context 'when there is no previous cached response' do
      it 'makes an http call' do
        response = subject.get(url)
        expect(response.headers['server']).to be
      end

      it 'sets the new response onto the cache' do
        expect { subject.get(url) }.to change {
          Routemaster::Config.cache_redis.hget("cache:#{url}", "v:,l:")
        }.from(nil).to("{\"field\":\"test\"}")
      end
    end

    context 'when there is a previous cached response' do
      before do
        subject.get(url)
      end

      it 'fetches the cached response' do
        expect(subject.get(url).body).to eq("{\"field\":\"test\"}")
      end

      it 'does not make an http call' do
        response = subject.get(url)
        expect(response.headers['server']).to be_nil
      end
    end
  end
end
