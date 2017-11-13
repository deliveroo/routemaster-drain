require 'spec_helper'
require 'spec/support/uses_dotenv'
require 'spec/support/uses_redis'
require 'spec/support/uses_webmock'
require 'routemaster/api_client'
require 'routemaster/api_client_circuit'

describe Routemaster::APIClientCircuit do
  uses_webmock
  uses_redis

  context "when enabled" do
    before do
      allow_any_instance_of(described_class).to receive(:enabled?){ true }
    end

    let(:url){ 'http://example.com/foobar' }

    def make_request_stub(method, url)
      stub_request(method, url).to_return(
        status:   status,
        body:     { id: 132, type: 'widget' }.to_json,
        headers:  {
          'content-type' => 'application/json;v=1'
        }
      )
    end

    shared_examples 'performing request' do
      context "when not erroring" do
        let(:status) { 200 }

        it "should pass through a response" do
          expect(request.call.status).to eq 200
        end
      end

      context "when erroring" do
        let(:status){ 500 }

        it "should pass through a single error" do
          expect{ request.call }.to raise_error Routemaster::Errors::FatalResource
          expect(stubbed_request).to have_been_requested
        end

        context "after lots of errors" do
          before do
            60.times do
              request.call rescue Routemaster::Errors::FatalResource
            end
          end
          it "should limit the amount of requests" do
            expect(stubbed_request).to have_been_made.at_least_times(49)
            expect(stubbed_request).to have_been_made.at_most_times(51)
          end
        end
      end
    end

    describe '#get' do
      let(:request) do
        -> { Routemaster::APIClient.new.get(url) }
      end
      let!(:stubbed_request) { make_request_stub(:get, url) }

      include_examples 'performing request'
    end

    describe '#post' do
      let(:request) do
        -> { Routemaster::APIClient.new.post(url) }
      end
      let!(:stubbed_request) { make_request_stub(:post, url) }

      include_examples 'performing request'
    end

    describe '#patch' do
      let(:request) do
        -> { Routemaster::APIClient.new.patch(url) }
      end

      let!(:stubbed_request) { make_request_stub(:patch, url) }

      include_examples 'performing request'
    end

    describe '#delete' do
      let(:request) do
        -> { Routemaster::APIClient.new.delete(url) }
      end

      let!(:stubbed_request) { make_request_stub(:delete, url) }

      include_examples 'performing request'
    end
  end
end
