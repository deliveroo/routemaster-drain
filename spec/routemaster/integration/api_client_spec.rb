require 'spec_helper'
require 'spec/support/uses_redis'
require 'spec/support/uses_dotenv'
require 'spec/support/uses_webmock'
require 'spec/support/server'
require 'spec/support/breakpoint_class'
require 'routemaster/api_client'
require 'routemaster/cache'
require 'dogstatsd'

describe Routemaster::APIClient do
  def now
    (Time.now.to_f * 1e6).to_i
  end

  uses_dotenv
  uses_redis
  uses_webmock

  let(:port) { 8000 }
  let(:service) do
    TestServer.new(port) do |server|
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

  before { service.start }
  after { service.stop }

  before { WebMock.disable_net_connect!(allow_localhost: true) }

  let(:host) { "http://localhost:#{port}" }

  describe 'error handling' do

    shared_examples 'exception raiser' do
      it 'raises an ResourceNotFound on 404' do
        expect { perform.(host + '/404') }.to raise_error(Routemaster::Errors::ResourceNotFound)
      end

      it 'raises an InvalidResource on 400' do
        expect { perform.(host + '/400') }.to raise_error(Routemaster::Errors::InvalidResource)
      end

      it 'raises an UnauthorizedResourceAccess on 401' do
        expect { perform.(host + '/401') }.to raise_error(Routemaster::Errors::UnauthorizedResourceAccess)
      end

      it 'raises an UnauthorizedResourceAccess on 403' do
        expect { perform.(host + '/403') }.to raise_error(Routemaster::Errors::UnauthorizedResourceAccess)
      end

      it 'raises an ConflictResource on 409' do
        expect { perform.(host + '/409') }.to raise_error(Routemaster::Errors::ConflictResource)
      end

      it 'raises an IncompatibleVersion on 412' do
        expect { perform.(host + '/412') }.to raise_error(Routemaster::Errors::IncompatibleVersion)
      end

      it 'raises an InvalidResource on 413' do
        expect { perform.(host + '/413') }.to raise_error(Routemaster::Errors::InvalidResource)
      end

      it 'raises an ResourceThrottling on 429' do
        expect { perform.(host + '/429') }.to raise_error(Routemaster::Errors::ResourceThrottling)
      end

      it 'raises an FatalResource on 500' do
        expect { perform.(host + '/500') }.to raise_error(Routemaster::Errors::FatalResource)
      end
    end

    describe '#get' do
      let(:perform) { ->(uri) { subject.get(uri) } }
      include_examples 'exception raiser'
    end

    describe '#fget' do
      let(:perform) { ->(uri) { subject.fget(uri).value } }
      include_examples 'exception raiser'
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

        context 'when the cache gets invalidated' do
          before { Routemaster::Cache.new.invalidate(url) }

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

  describe 'interleaved requests' do
    let(:url) { "#{host}/resources/1" }

    let(:processes) do
      Array.new(2) do
        ForkBreak::Process.new do
          breakpoint_class(Routemaster::Middleware::ResponseCaching, :fetch_from_service)
          Routemaster::Cache.new.send(cache_method, url)
          subject.get(url).body
        end
      end
    end

    let(:first_timestamp) do
      processes[0].return_value.updated_at
    end

    let(:second_timestamp) do
      processes[1].return_value.updated_at
    end

    let(:fresh_timestamp) do
      subject.get(url).body.updated_at
    end

    before do
      processes.first.run_until(:before_fetch_from_service).wait
      processes.last.finish.wait
      processes.first.finish.wait
    end

    context 'the cache is busted between requests' do
      let(:cache_method) { :bust }

      it 'should return the first_timestamp' do
        expect(first_timestamp).to eq fresh_timestamp
      end

      it 'returns a second timestamp older than the first' do
        expect(second_timestamp).to be < first_timestamp
      end
    end

    context 'the cache is invalidated between requests' do
      let(:cache_method) { :invalidate }

      it 'returns a second timestamp older than the first' do
        expect(second_timestamp).to be < first_timestamp
      end

      it 'returns an invalid first request' do
        expect(first_timestamp).to be < fresh_timestamp
      end

      it 'returns an invalid second request' do
        expect(second_timestamp).to be < fresh_timestamp
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

  describe 'telemetry' do
    let(:metrics_client) { Dogstatsd.new }
    let(:source_peer) { 'test_service' }
    let(:url) { "#{host}/success" }

    subject do
      Routemaster::APIClient.new(metrics_client: metrics_client,
                                 source_peer: source_peer)
    end

    before do
      allow(metrics_client).to receive(:increment).and_call_original
      allow(metrics_client).to receive(:time).and_call_original
    end

    context 'when metrics source peer is absent' do
      let(:source_peer) { nil }

      it 'does not send metrics' do
        subject.get(url)
        expect(metrics_client).not_to have_received(:increment)
      end
    end

    it 'sends request metrics' do
      subject.get(url)
      expect(metrics_client).to have_received(:increment).with(
        'api_client.request.count', tags: %w[source:test_service destination:localhost verb:get]
      )
    end

    it 'sends response metrics' do
      subject.get(url)
      expect(metrics_client).to have_received(:increment).with(
        'api_client.response.count', tags: %w[source:test_service destination:localhost status:200]
      )
    end

    it 'sends timing metrics' do
      subject.get(url)
      expect(metrics_client).to have_received(:time).with(
        'api_client.latency', tags: %w[source:test_service destination:localhost verb:get]
      )
    end
  end
end
