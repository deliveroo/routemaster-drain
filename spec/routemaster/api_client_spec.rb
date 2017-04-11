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
        expect(req.headers).to include('X-Custom-Header')
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

  describe '#get' do
    subject { fetcher.get(url, headers: headers) }
    it_behaves_like 'a GET requester'
    it_behaves_like 'a wrappable response'
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
  end

  describe '#patch' do
    subject { fetcher.patch(url, body: {}, headers: headers) }

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

  describe '#with_response' do
    before { stub_request(:any, //).to_return(status: 200) }

    class DummyResponseA
      def initialize(res, client: nil); end
      def dummy_a; true; end
    end

    class DummyResponseB
      def initialize(res, client: nil); end
      def dummy_b; true; end
    end

    subject { described_class.new(response_class: DummyResponseA) }
    let(:response) { subject.get('https://example.com') }

    it 'changes the response wrapper during the block' do
      subject.with_response(DummyResponseB) do
        expect(response).to respond_to(:dummy_b)
      end
    end

    it 'restores the original response wrapper after the block' do
      subject.with_response(DummyResponseB) {}
      expect(response).to respond_to(:dummy_a)
    end
  end
end
