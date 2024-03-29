require 'spec_helper'
require 'spec/support/uses_dotenv'
require 'spec/support/uses_redis'
require 'spec/support/uses_webmock'
require 'routemaster/api_client'
require 'json'

describe Routemaster::APIClient do
  uses_dotenv
  uses_redis
  uses_webmock

  let(:url) { 'https://example.com/widgets/132' }
  let(:headers) {{}}
  let(:fetcher) { described_class.new }

  shared_examples 'a GET requester' do
    before do
      @req = stub_request(:get, /example\.com/).to_return(
        status:   200,
        body:     { id: 132, type: 'widget' }.to_json,
        headers:  {
          'content-type' => 'application/json;v=1'
        }
      )
    end

    it 'GETs from the URL' do
      subject.status
      expect(@req).to have_been_requested
    end

    it 'has :status, :headers, :body' do
      expect(subject.status).to eq(200)
      expect(subject.headers).to have_key('content-type')
      expect(subject.body).not_to be_nil
    end

    it 'mashifies body' do
      expect(subject.body.id).to eq(132)
    end

    it 'uses auth' do
      subject.status
      assert_requested(:get, /example/) do |req|
        credentials = Base64.strict_encode64('username:s3cr3t')
        expect(req.headers['Authorization']).to eq("Basic #{credentials}")
      end
    end

    it 'passes headers' do
      headers['x-custom-header'] = 'why do you even'
      subject.status
      assert_requested(:get, /example/) do |req|
        expect(req.headers.keys).to include('X-Custom-Header')
        expect(req.headers['User-Agent']).to eql "RoutemasterDrain - Faraday v#{Faraday::VERSION}"
      end
    end

    describe 'source peer' do
      context 'with a source peer' do
        let(:options) { { source_peer: 'ServiceA' } }
        let(:fetcher) { described_class.new(options) }

        it 'should set the user agent header to the source peer' do
          subject.status
          assert_requested(:get, /example/) do |req|
            expect(req.headers).to include('User-Agent' => 'ServiceA')
          end
        end
      end

      context 'without a source peer' do
        let(:options) { { source_peer: nil } }
        let(:fetcher) { described_class.new(options) }

        it 'should set the user agent header to the faraday version' do
          subject.status
          assert_requested(:get, /example/) do |req|
            expect(req.headers).to include('User-Agent' => "RoutemasterDrain - Faraday v#{Faraday::VERSION}" )
          end
        end
      end
    end
  end

  shared_examples 'a wrappable response' do
    context 'when response_class is present' do
      before do
        @req = stub_request(:get, /example\.com/).to_return(
          status:   200,
          body:     { id: 132, type: 'widget' }.to_json,
          headers:  {
            'content-type' => 'application/json;v=1'
          }
        )

        class DummyResponse
          def initialize(res, client: nil); end
          def dummy; true; end
        end
      end

      let(:fetcher) { described_class.new(response_class: DummyResponse) }

      it 'wraps the response in the response class' do
        expect(subject.dummy).to be_truthy
      end
    end
  end

  shared_examples 'a circuit breaker wrapped request' do
    let(:fetcher) { described_class.new(retry_attempts: 0) }
    let(:url)     { 'https://circuit.example.com/circuit/132' }
    let(:method)  { :get }

    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV)
        .to receive(:fetch)
        .with('ROUTEMASTER_ENABLE_API_CLIENT_CIRCUIT', 'NO').and_return('YES')
      allow(ENV)
        .to receive(:fetch)
        .with('ROUTEMASTER_CIRCUIT_BREAKER_ERROR_THRESHOLD', 50).and_return('1')
      allow(ENV)
        .to receive(:fetch)
        .with('ROUTEMASTER_CIRCUIT_BREAKER_VOLUME_THRESHOLD', 50).and_return('1')

      stub_request(method, url).to_timeout
    end

    it 'trips after the second request' do
      5.times { expect { subject }.to raise_error StandardError }
      expect(a_request(method, url)).to have_been_made.at_most_times(2)
    end
  end

  describe '#get' do
    subject { fetcher.get(url, headers: headers) }

    it_behaves_like 'a GET requester'
    it_behaves_like 'a wrappable response'
    it_behaves_like 'a circuit breaker wrapped request'
  end

  describe '#fget' do
    subject { fetcher.fget(url, headers: headers) }
    it_behaves_like 'a GET requester'
    it_behaves_like 'a wrappable response'

    context "when setting callbacks" do
      before do
        stub_request(:get, /example\.com/).to_return(
          status:   status,
          body:     { id: 132, type: 'widget' }.to_json,
          headers:  {
            'content-type' => 'application/json;v=1'
          }
        )
      end

      let(:callback_spy) { spy('callback_spy') }

      subject do
        fetcher.fget(url, headers: headers)
      end

      let(:callback){
        subject.on_success { callback_spy.success }.zip(subject.on_error { callback_spy.error })
      }

      context "when successful" do
        let(:status){ 200 }
        it "calls on_success" do
          expect(subject.status).to eq 200
          callback.value #We need to wait before testing if the spy was called
          expect(callback_spy).to have_received(:success)
          expect(callback_spy).not_to have_received(:error)

        end
      end

      context "when not successful" do
        let(:status){ 500 }
        it "calls on_error" do
          expect{subject.value}.to raise_error { Routemaster::Errors::FatalResource }
          callback.value #We need to wait before testing if the spy was called
          expect(callback_spy).to have_received(:error)
          expect(callback_spy).not_to have_received(:success)
        end
      end
    end
  end

  describe '#post' do
    subject { fetcher.post(url, body: {}, headers: headers) }

    before do
      @post_req = stub_request(:post, /example\.com/).to_return(
        status:   200,
        body:     { id: 132, type: 'widget' }.to_json,
        headers:  {
          'content-type' => 'application/json;v=1'
        }
      )
    end

    it 'POSTs from the URL' do
      subject
      expect(@post_req).to have_been_requested
    end

    it_behaves_like 'a wrappable response'
    it_behaves_like 'a circuit breaker wrapped request' do
      let(:method) { :post }
    end
  end

  describe '#put' do
    let(:body) { { 'one' => 1, 'two' => 2 }.to_json }
    subject { fetcher.put(url, body: body, headers: headers) }

    context 'when request succeeds' do
      before do
        @put_req= stub_request(:put, /example\.com/).to_return(
          status:   200,
          body:     { id: 132, type: 'widget' }.to_json,
          headers:  {
            'content-type' => 'application/json;v=1'
          }
        )
      end

      it 'PUT from the URL' do
        subject
        expect(@put_req).to have_been_requested
      end

      it_behaves_like 'a wrappable response'
      it_behaves_like 'a circuit breaker wrapped request' do
        let(:method) { :put }
      end
    end

    context 'when request times out' do
      subject do
        begin
          fetcher.put(url, body: body, headers: headers)
        rescue Faraday::TimeoutError
        end
      end

      before do
        stub_request(:put, url).to_timeout
      end

      it 'tries the PUT request three times' do
        subject
        assert_requested(:put, url, body: body, times: 3)
      end

      context 'when retry attempt count is specified' do
        let(:retry_attempts) { 4 }
        let(:fetcher) { described_class.new(retry_attempts: retry_attempts) }

        it "tries the PUT request '1 + retry-count' times" do
          subject
          assert_requested(:put, url, body: body, times: 1 + retry_attempts)
        end
      end
    end

    context 'when request raises fatal resource exception' do
      let(:env) { double(body: body, url: url, method: 'PUT') }

      subject do
        begin
          fetcher.put(url, body: body, headers: headers)
        rescue Routemaster::Errors::FatalResource
        end
      end

      before do
        stub_request(:put, url).to_raise(Routemaster::Errors::FatalResource.new(env))
      end

      context 'when retry exceptions is specified' do
        let(:fetcher) { described_class.new(retry_exceptions: [ Routemaster::Errors::FatalResource ]) }

        it 'tries to PUT request three times' do
          subject
          assert_requested(:put, url, body: body, times: 3)
        end
      end
    end
  end

  describe '#patch' do
    let(:body) { { 'one' => 1, 'two' => 2 }.to_json }
    subject { fetcher.patch(url, body: body, headers: headers) }

    context 'when request succeeds' do
      before do
        @patch_req = stub_request(:patch, /example\.com/).to_return(
          status:   200,
          body:     { id: 132, type: 'widget' }.to_json,
          headers:  {
            'content-type' => 'application/json;v=1'
          }
        )
      end

      it 'PATCH from the URL' do
        subject
        expect(@patch_req).to have_been_requested
      end

      it_behaves_like 'a wrappable response'
      it_behaves_like 'a circuit breaker wrapped request' do
        let(:method) { :patch }
      end
    end

    context 'when request times out' do
      subject do
        begin
          fetcher.patch(url, body: body, headers: headers)
        rescue Faraday::TimeoutError
        end
      end

      before do
        stub_request(:patch, url).to_timeout
      end

      it 'tries the PATCH request only once' do
        subject
        assert_requested(:patch, url, body: body, times: 1)
      end

      context 'when PATCH is specified as a method to retry' do
        let(:retry_methods) { [:patch] }
        let(:fetcher) { described_class.new(retry_methods: retry_methods) }

        it 'tries the PATCH request 3 times' do
          subject
          assert_requested(:patch, url, body: body, times: 3)
        end

        context 'when retry attempt count is specified' do
          let(:retry_attempts) { 4 }
          let(:fetcher) { described_class.new(retry_methods: retry_methods, retry_attempts: retry_attempts) }

          it "tries the PATCH request '1 + retry-count' times" do
            subject
            assert_requested(:patch, url, body: body, times: 1 + retry_attempts)
          end
        end
      end
    end
  end

  describe '#delete' do
    subject { fetcher.delete(url, headers: headers) }

    before do
      @delete_req = stub_request(:delete, /example\.com/).to_return(
        status:   204,
      )
    end

    it 'DELETES from the URL' do
      subject
      expect(@delete_req).to have_been_requested
    end
  end

  describe '#discover' do
    before do
      @req = stub_request(:get, /example\.com/).to_return(
        status:   200,
        body:     { id: 132, type: 'widget' }.to_json,
        headers:  {
          'content-type' => 'application/json;v=1'
        }
      )
    end

    it 'GETs from the URL' do
      subject.discover('https://example.com')
      expect(@req).to have_been_requested
    end
  end
end
