require 'spec_helper'
require 'spec/support/uses_redis'
require 'spec/support/uses_dotenv'
require 'routemaster/api_client'
require 'routemaster/cache'
require 'webrick'
require 'dogstatsd'

RSpec.describe 'Api client integration specs' do
  module WEBrick
    module HTTPServlet
      class ProcHandler
        alias do_PATCH do_GET
      end
    end
  end

  def now
    (Time.now.to_f * 1e6).to_i
  end

  uses_dotenv
  uses_redis

  let!(:log) { WEBrick::Log.new '/dev/null' }
  let(:port) { 8000 }
  let(:service) do
    WEBrick::HTTPServer.new(Port: port, DocumentRoot: Dir.pwd, Logger: log).tap do |server|
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
        res.body = { attribute: 'value', updated_at: now }.to_json
      end

      server.mount_proc "/discover" do |req, res|
        res['Content-Type'] = 'application/json'
        res.status = 200
        res.body = { _links: { resources: { href: "http://localhost:#{port}/resources" } } }.to_json
      end

      server.mount_proc "/resources" do |req, res|
        res['Content-Type'] = 'application/json'
        res.status = 200
        case req.query_string
        when "first_name=roo"
          res.body = {
            _links: {
              self: {
                href: "http://localhost:#{port}/resourcess?first_name=roo&page=1&per_page=2"
              },
              first: {
                href: "http://localhost:#{port}/resources?first_name=roo&page=1&per_page=2"
              },
              last: {
                href: "http://localhost:#{port}/resources?first_name=roo&page=3&per_page=2"
              },
              next: {
                href: "http://localhost:#{port}/resources?first_name=roo&page=2&per_page=2"
              },
              resources: [
                { href: "http://localhost:#{port}/resources/1" },
                { href: "http://localhost:#{port}/resources/1" }
              ]
            }
          }.to_json
        when "first_name=roo&page=2&per_page=2"
          res.body = {
            _links: {
              self: {
                href: "http://localhost:#{port}/resourcess?first_name=roo&page=2&per_page=2"
              },
              first: {
                href: "http://localhost:#{port}/resources?first_name=roo&page=1&per_page=2"
              },
              last: {
                href: "http://localhost:#{port}/resources?first_name=roo&page=3&per_page=2"
              },
              next: {
                href: "http://localhost:#{port}/resources?first_name=roo&page=3&per_page=2"
              },
              resources: [
                { href: "http://localhost:#{port}/resources/1" },
                { href: "http://localhost:#{port}/resources/1" }
              ]
            }
          }.to_json
        when "first_name=roo&page=3&per_page=2"
          res.body = {
            _links: {
              self: {
                href: "http://localhost:#{port}/resourcess?first_name=roo&page=3&per_page=2"
              },
              first: {
                href: "http://localhost:#{port}/resources?first_name=roo&page=1&per_page=2"
              },
              last: {
                href: "http://localhost:#{port}/resources?first_name=roo&page=3&per_page=2"
              },
              resources: [
                { href: "http://localhost:#{port}/resources/1" }
              ]
            }
          }.to_json
        end
      end
    end
  end

  before do
    @pid = fork do
      # $stderr.close
      $stderr.close
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
    # sleep(0.5) # leave sometime for the previous webrick to teardown
  end

  after do
    Process.kill('KILL', @pid)
    Process.wait(@pid)
  end

  subject { Routemaster::APIClient.new }
  let(:host) { "http://localhost:#{port}" }

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


  describe 'caching behaviour' do
    let(:url) { "#{host}/resources/1" }
    def timestamp ; subject.get(url).body.updated_at ; end

    describe 'GET requests' do
      context 'when the resource was fetched' do
        let!(:cached_stamp) { timestamp }
        let(:fetched_stamp) { timestamp }

        it 'returns the cached response' do
          expect(fetched_stamp).to eq(cached_stamp)
        end

        context 'when the cache gets busted' do
          before { Routemaster::Cache.new.bust(url) }

          it 'returns a fresh response' do
            expect(fetched_stamp).to be > cached_stamp
          end
        end
      end
    end

    describe 'PATCH request' do
      context 'when the resource was fetched' do
        let!(:cached_stamp) { timestamp }
        let(:fetched_stamp) { timestamp }

        it 'invalidates the cache on update' do
          subject.patch(url, body: {})
          expect(fetched_stamp).to be > cached_stamp
        end
      end
    end

    describe 'DELETE request' do
      context 'when the resource was fetched' do
        let!(:cached_stamp) { timestamp }
        let(:fetched_stamp) { timestamp }

        it 'invalidates the cache on destroy' do
          subject.delete(url)
          expect(fetched_stamp).to be > cached_stamp
        end
      end
    end
  end


  describe 'INDEX request' do
    let(:url) { "http://localhost:#{port}/discover" }

    subject do
      Routemaster::APIClient.new(response_class: Routemaster::Responses::HateoasResponse)
    end

    it 'traverses through pagination next all links that match the request params' do
      res = subject.discover(url)
      expect(res.resources.index(filters: { first_name: 'roo' }).count).to eq(5)
    end

    it 'does not make any http requests to fetch resources any if just the index method is called' do
      resources = subject.discover(url).resources

      expect(subject).to receive(:get).with("http://localhost:#{port}/resources", anything).once
      resources.index
    end
  end

  describe 'Telemetry' do
    let(:metrics_client) { Dogstatsd.new }
    let(:source_peer) { 'test_service' }
    let(:url) { "#{host}/success" }
    let(:calls) { [] } 

    subject do
      Routemaster::APIClient.new(metrics_client: metrics_client,
                                 source_peer: source_peer)
    end

    before do
      wrapper = -> (m, *args, &block) {
        calls << [m.name, *args]
        m.call(*args, &block)
      }
      allow(metrics_client).to receive(:increment).and_wrap_original(&wrapper)
      allow(metrics_client).to receive(:time).and_wrap_original(&wrapper)
    end

    context 'when metrics source peer is absent' do
      let(:source_peer) { nil }

      it 'does not send metrics' do
        subject.get(url)
        expect(calls).to be_empty
      end
    end

    it 'sends request metrics' do
      subject.get(url)
      expect(calls).to include([:increment, 'api_client.request.count', tags: %w[source:test_service destination:localhost verb:get]])
    end

    it 'sends response metrics' do
      subject.get(url)
      expect(calls).to include([
        :increment, 'api_client.response.count', tags: %w[source:test_service destination:localhost status:200]
      ])
    end

    it 'sends timing metrics' do
      subject.get(url)
      expect(calls).to include([
        :time, 'api_client.latency', tags: %w[source:test_service destination:localhost verb:get]
      ])
    end
  end
end
