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

  describe '.get' do
    let(:url) { 'https://example.com/widgets/132' }
    let(:headers) {{}}
    let(:fetcher) { described_class.new }
    subject { fetcher.get(url, headers: headers) }

    before do
      @req = stub_request(:get, /example\.com/).to_return(
        status:   200,
        body:     { id: 132, type: 'widget' }.to_json,
        headers:  {
          'content-type' => 'application/json;v=1'
        }
      )

      @post_req = stub_request(:post, /example\.com/).to_return(
        status:   200,
        body:     { id: 132, type: 'widget' }.to_json,
        headers:  {
          'content-type' => 'application/json;v=1'
        }
      )
    end

    it 'GETs from the URL' do
      subject
      expect(@req).to have_been_requested
    end

    context 'POST request' do
      subject { fetcher.post(url, body: {}, headers: headers) }

      it 'POSTs from the URL' do
        subject
        expect(@post_req).to have_been_requested
      end
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
      subject
      assert_requested(:get, /example/) do |req|
        credentials = Base64.strict_encode64('username:s3cr3t')
        expect(req.headers['Authorization']).to eq("Basic #{credentials}")
      end
    end

    it 'passes headers' do
      headers['x-custom-header'] = 'why do you even'
      subject
      assert_requested(:get, /example/) do |req|
        expect(req.headers).to include('X-Custom-Header')
      end
    end

    context 'when response_class is present' do
      before do
        class DummyResponse
          def initialize(res, client: nil); end
        end
      end

      let(:fetcher) { described_class.new(response_class: DummyResponse) }

      it 'returns a response_class instance as a response' do
        expect(subject).to be_an_instance_of(DummyResponse)
      end
    end
  end
end
