require 'spec_helper'
require 'spec/support/uses_redis'
require 'spec/support/uses_dotenv'
require 'routemaster/cache'
require 'webrick'

RSpec.describe 'Requests with caching' do
  uses_dotenv
  uses_redis

  let!(:log) { WEBrick::Log.new '/dev/null' }
  let(:service) do
    WEBrick::HTTPServer.new(Port: 8000, DocumentRoot: Dir.pwd, Logger: log).tap do |server|
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
    sleep(0.5) # leave sometime for the previous webrick to teardown
  end

  after do
    Process.kill('KILL', @pid)
    Process.wait(@pid)
  end

  subject { Routemaster::Cache.new }

  describe 'GET request' do
    let(:body_cache_keys) { ["cache:#{url}", "v:,l:,body"] }
    let(:event_index_cache_keys) { ["cache:#{url}", "event_index"] }
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

      it "sets the event_index onto the cache" do
        current = Routemaster::EventIndex.new(url).increment
        expect { subject.get(url) }
          .to change { Routemaster::Config.cache_redis.hget(*event_index_cache_keys)}
          .from(nil)
          .to(current.to_s)
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

      context "if the event index is incremented" do

        before { Routemaster::EventIndex.new(url).increment }

        it 'does make a http call' do
          response = subject.get(url)
          expect(response.env.request).not_to be_empty
        end
      end
    end
  end
end
