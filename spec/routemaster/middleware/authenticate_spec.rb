require 'spec_helper'
require 'spec/support/rack_test'
require 'spec/support/events'
require 'routemaster/middleware/authenticate'
require 'json'

describe Routemaster::Middleware::Authenticate do
  let(:app) { described_class.new(ErrorRackApp.new, options) }
  let(:listener) { double 'listener', on_authenticate: nil }
  let(:options) {{ uuid: 'demo' }}
  
  def perform
    post '/whatever'
  end
  
  before { Wisper.add_listener(listener, scope: described_class.name, prefix: true) }
  after { Wisper::GlobalListeners.clear }

  context 'with valid credentials' do
    before { authorize 'demo', 'x' }

    it 'passes' do
      perform
      expect(last_response.status).to eq(501) # 501 from ErrorRackApp
    end

    it 'broadcasts :authenticate :succeeded' do
      expect(listener).to receive(:on_authenticate).with(:succeeded, anything)
      perform
    end
  end

  context 'with invalid credentials' do
    before { authorize 'h4xx0r', 'x' }

    it 'fails' do
      perform
      expect(last_response.status).to eq(403)
    end

    it 'broadcasts :authenticate :failed' do
      expect(listener).to receive(:on_authenticate).with(:failed, anything)
      perform
    end
  end

  context 'without credentials' do
    it 'fails' do
      perform
      expect(last_response.status).to eq(401)
    end

    it 'broadcasts :authenticate :missing' do
      expect(listener).to receive(:on_authenticate).with(:missing, anything)
      perform
    end
  end
end

