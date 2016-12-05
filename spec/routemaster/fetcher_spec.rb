require 'spec_helper'
require 'spec/support/uses_dotenv'
require 'spec/support/uses_redis'
require 'spec/support/uses_webmock'
require 'routemaster/fetcher'
require 'json'

describe Routemaster::Fetcher do
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
    end

    it 'GETs from the URL' do
      subject
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
      subject
      assert_requested(:get, /example/) do |req|
        expect(req.uri.userinfo).to eq('username:s3cr3t')
      end
    end

    it 'passes headers' do
      headers['x-custom-header'] = 'why do you even'
      subject
      assert_requested(:get, /example/) do |req|
        expect(req.headers).to include('X-Custom-Header')
      end
    end
  end
end
