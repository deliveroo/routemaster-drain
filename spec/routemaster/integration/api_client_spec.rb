require 'spec_helper'
require 'spec/support/uses_redis'
require 'spec/support/uses_dotenv'
require 'routemaster/api_client'
require 'webrick'

RSpec.describe 'Api client integration specs' do
  module WEBrick
    module HTTPServlet
      class ProcHandler
        alias do_PATCH do_GET
      end
    end
  end

  uses_dotenv
  uses_redis

  let!(:log) { WEBrick::Log.new '/dev/null' }
  let(:service) do
    WEBrick::HTTPServer.new(Port: 8000, DocumentRoot: Dir.pwd, Logger: log).tap do |server|
      [400, 401, 403, 404, 409, 412, 413, 429, 500].each do |status_code|
        server.mount_proc "/#{status_code}" do |req, res|
          res.status = status_code
          res.body = { field: 'test' }.to_json
        end
      end

      server.mount_proc "/success" do |req, res|
        res.status = 200
        res.body = { field: 'test' }.to_json
      end

      server.mount_proc "/resources/1" do |req, res|
        res['Content-Type'] = 'application/json'
        res.status = 200
        res.body = { attribute: 'value' }.to_json
      end

      server.mount_proc "/discover" do |req, res|
        res['Content-Type'] = 'application/json'
        res.status = 200
        res.body = { _links: { resources: { href: 'http://localhost:8000/resources' } } }.to_json
      end

      server.mount_proc "/resources" do |req, res|
        res['Content-Type'] = 'application/json'
        res.status = 200
        case req.query_string
        when "first_name=roo"
          res.body = {
            _links: {
              self: {
                href: "http://localhost:8000/resourcess?first_name=roo&page=1&per_page=2"
              },
              first: {
                href: "http://localhost:8000/resources?first_name=roo&page=1&per_page=2"
              },
              last: {
                href: "http://localhost:8000/resources?first_name=roo&page=3&per_page=2"
              },
              next: {
                href: "http://localhost:8000/resources?first_name=roo&page=2&per_page=2"
              },
              resources: [
                { href: 'http://localhost:8000/resources/1' },
                { href: 'http://localhost:8000/resources/1' }
              ]
            }
          }.to_json
        when "first_name=roo&page=2&per_page=2"
          res.body = {
            _links: {
              self: {
                href: "http://localhost:8000/resourcess?first_name=roo&page=2&per_page=2"
              },
              first: {
                href: "http://localhost:8000/resources?first_name=roo&page=1&per_page=2"
              },
              last: {
                href: "http://localhost:8000/resources?first_name=roo&page=3&per_page=2"
              },
              next: {
                href: "http://localhost:8000/resources?first_name=roo&page=3&per_page=2"
              },
              resources: [
                { href: 'http://localhost:8000/resources/1' },
                { href: 'http://localhost:8000/resources/1' }
              ]
            }
          }.to_json
        when "first_name=roo&page=3&per_page=2"
          res.body = {
            _links: {
              self: {
                href: "http://localhost:8000/resourcess?first_name=roo&page=3&per_page=2"
              },
              first: {
                href: "http://localhost:8000/resources?first_name=roo&page=1&per_page=2"
              },
              last: {
                href: "http://localhost:8000/resources?first_name=roo&page=3&per_page=2"
              },
              resources: [
                { href: 'http://localhost:8000/resources/1' }
              ]
            }
          }.to_json
        end
      end
    end
  end

  before do
    @pid = fork do
      trap 'INT' do service.shutdown end
      service.start
    end
    # wait until the server is up
    Timeout.timeout(1) do
      loop do
        begin
          TCPSocket.new('localhost', '8000')
        rescue Errno::ECONNREFUSED
          next
        end
        break
      end
    end
  end

  after do
    Process.kill('KILL', @pid)
    Process.wait(@pid)
  end

  subject { Routemaster::APIClient.new }
  let(:host) { 'http://localhost:8000' }

  describe 'error handling' do
    it 'raises an ResourceNotFound on 404' do
      expect { subject.get(host + '/404') }.to raise_error(Routemaster::Errors::ResourceNotFound)
    end

    it 'raises an InvalidResource on 400' do
      expect { subject.get(host + '/400') }.to raise_error(Routemaster::Errors::InvalidResource)
    end

    it 'raises an UnauthorizedResourceAccess on 401' do
      expect { subject.get(host + '/401') }.to raise_error(Routemaster::Errors::UnauthorizedResourceAccess)
    end

    it 'raises an UnauthorizedResourceAccess on 403' do
      expect { subject.get(host + '/403') }.to raise_error(Routemaster::Errors::UnauthorizedResourceAccess)
    end

    it 'raises an ConflictResource on 409' do
      expect { subject.get(host + '/409') }.to raise_error(Routemaster::Errors::ConflictResource)
    end

    it 'raises an IncompatibleVersion on 412' do
      expect { subject.get(host + '/412') }.to raise_error(Routemaster::Errors::IncompatibleVersion)
    end

    it 'raises an InvalidResource on 413' do
      expect { subject.get(host + '/413') }.to raise_error(Routemaster::Errors::InvalidResource)
    end

    it 'raises an ResourceThrottling on 429' do
      expect { subject.get(host + '/429') }.to raise_error(Routemaster::Errors::ResourceThrottling)
    end

    it 'raises an FatalResource on 500' do
      expect { subject.get(host + '/500') }.to raise_error(Routemaster::Errors::FatalResource)
    end
  end

  describe 'Future GET request' do
    let(:body_cache_keys) { ["cache:#{url}", "v:,l:,body"] }
    let(:headers_cache_keys) { ["cache:#{url}", "v:,l:,headers"] }
    let(:url) { "#{host}/success" }

    context 'when there is a previous cached resource' do
      let(:cache) { Routemaster::Config.cache_redis }

      it 'returns the response from within the future' do
        expect(cache.hget("cache:#{url}", "v:,l:,body")).to be_nil

        future = subject.fget(url)
        expect(future).to be_an_instance_of(Routemaster::Responses::FutureResponse)

        future.value
        expect(cache.hget("cache:#{url}", "v:,l:,body")).to be
      end
    end
  end

  describe 'PATCH request' do
    let(:body_cache_keys) { ["cache:#{url}", "v:,l:,body"] }
    let(:headers_cache_keys) { ["cache:#{url}", "v:,l:,headers"] }
    let(:url) { "#{host}/success" }

    context 'when there is a previous cached resource' do
      before { subject.get(url) }
      let(:cache) { Routemaster::Config.cache_redis }

      it 'invalidates the cache on update' do
        expect(cache.hget("cache:#{url}", "v:,l:,body")).to be
        subject.patch(url, body: {})

        expect(cache.hget("cache:#{url}", "v:,l:,body")).to be_nil

        subject.get(url)
        expect(cache.hget("cache:#{url}", "v:,l:,body")).to be
      end
    end
  end

  describe 'DELETE request' do
    let(:body_cache_keys) { ["cache:#{url}", "v:,l:,body"] }
    let(:headers_cache_keys) { ["cache:#{url}", "v:,l:,headers"] }
    let(:url) { "#{host}/success" }

    context 'when there is a previous cached resource' do
      before { subject.get(url) }
      let(:cache) { Routemaster::Config.cache_redis }

      it 'invalidates the cache on destroy' do
        expect(cache.hget("cache:#{url}", "v:,l:,body")).to be
        subject.delete(url)

        expect(cache.hget("cache:#{url}", "v:,l:,body")).to be_nil

        subject.get(url)
        expect(cache.hget("cache:#{url}", "v:,l:,body")).to be
      end
    end
  end

  describe 'INDEX request' do
    let(:url) { 'http://localhost:8000/discover' }

    subject do
      Routemaster::APIClient.new(response_class: Routemaster::Responses::HateoasResponse)
    end

    it 'traverses through pagination next all links that match the request params' do
      res = subject.discover(url)
      expect(res.resources.index(filters: { first_name: 'roo' }).count).to eq(5)
    end

    it 'does not make any http requests to fetch resources any if just the index method is called' do
      resources = subject.discover(url).resources

      expect(subject).to receive(:get).with("http://localhost:8000/resources", anything).once
      resources.index
    end
  end

  describe 'Telemetry' do
    let(:metrics_client) { double('MetricsClient') }
    let(:source_peer) { 'test_service' }
    let(:url) { "#{host}/success" }

    subject do
      Routemaster::APIClient.new(metrics_client: metrics_client,
                                 source_peer: source_peer)
    end

    context 'when metrics source peer is absent' do
      subject { Routemaster::APIClient.new(metrics_client: metrics_client) }

      it 'does not send metrics' do
        expect(metrics_client).to receive(:increment).never
        subject.get(url)
      end
    end

    it 'does send request metrics' do
      allow(metrics_client).to receive(:time).and_yield
      allow(metrics_client).to receive(:increment)
      expected_req_count_tags = ["source:test_service", "destination:localhost", "verb:get"]

      expect(metrics_client).to receive(:increment).with('api_client.request.count', tags: expected_req_count_tags)

      subject.get(url)
    end

    it 'does send response metrics' do
      allow(metrics_client).to receive(:increment)
      expected_res_count_tags = ["source:test_service", "destination:localhost", "status:200"]
      expected_latency_tags = ["source:test_service", "destination:localhost", "verb:get"]

      expect(metrics_client).to receive(:increment).with('api_client.response.count', tags: expected_res_count_tags)
      expect(metrics_client).to receive(:time).with('api_client.latency', tags: expected_latency_tags).and_yield

      subject.get(url)
    end
  end
end
