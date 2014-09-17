require 'spec_helper'
require 'spec/support/rack_test'
require 'spec/support/events'
require 'routemaster/middleware/root_post_only'

describe Routemaster::Middleware::RootPostOnly do
  let(:terminator) { ErrorRackApp.new }
  let(:app) { described_class.new(terminator) }

  describe '#call' do
    it 'passes for POST to root' do
      post '/'
      expect(last_response.status).to eq(501)
    end

    it '405s on non-POST' do
      get '/'
      expect(last_response.status).to eq(405)
    end

    it '404s on non-root path' do
      get '/why_not_even'
      expect(last_response.status).to eq(404)
    end

    context 'when mounted under another path' do
      let(:app) do
        Rack::Builder.new do
          map '/what' do
            use Routemaster::Middleware::RootPostOnly
            run ErrorRackApp.new
          end
        end
      end

      it 'passes for POST to mountpoint' do
        post '/what'
        expect(last_response.status).to eq(501)
      end
    end
  end
end




