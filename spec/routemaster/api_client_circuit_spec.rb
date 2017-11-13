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
      sb_req
      allow_any_instance_of(described_class).to receive(:enabled?){ true }
    end

    let(:url){ 'http://example.com/foobar' }

    let(:sb_req){
      stub_request(:get, url).to_return(
        status:   status,
        body:     { id: 132, type: 'widget' }.to_json,
        headers:  {
          'content-type' => 'application/json;v=1'
        }
      )
    }

    def perform
       Routemaster::APIClient.new.get(url)
    end

    context "when not erroring" do
      let(:status) { 200 }

      it "should pass through a response" do
        expect(perform.status).to eq 200
      end
    end

    context "when erroring" do
      let(:status){ 500 }

      it "should pass through a single error" do
        expect{ perform }.to raise_error Routemaster::Errors::FatalResource
        expect(sb_req).to have_been_requested
      end

      context "after lots of errors" do
        before do
          60.times do
            perform rescue Routemaster::Errors::FatalResource
          end
        end
        it "should limit the amount of requests" do
          expect(a_request(:get, url)).to have_been_made.at_least_times(49)
          expect(a_request(:get, url)).to have_been_made.at_most_times(51)
        end
      end
    end
  end
end
