require 'spec_helper'
require 'spec/support/rack_test'
require 'routemaster/receiver'

describe Routemaster::Receiver do
  let(:handler) { double 'handler', on_event: nil }
  let(:app) { described_class.new(fake_app, options) }
  let(:perform) { post '/events', payload, 'CONTENT_TYPE' => 'application/json' }
  
  let(:options) {{
    path:     '/events',
    uuid:     'demo',
    handler:  handler
  }}

  class FakeApp
    def call(env)
      [500, {}, 'fake app']
    end
  end

  let(:fake_app) { FakeApp.new }
  
  let(:payload) {[{
    topic: 'widgets', event: 'created', url: 'https://example.com/widgets/1', t: 1234
  }, {
    topic: 'widgets', event: 'created', url: 'https://example.com/widgets/2', t: 1234 
  }, {
    topic: 'widgets', event: 'created', url: 'https://example.com/widgets/3', t: 1234 
  }].to_json }


  it 'passes with valid HTTP Basic' do
    authorize 'demo', 'x'
    perform
    expect(last_response).to be_ok
  end

  it 'fails without authentication'
  it 'delegates to the next middleware for unknown paths'
  it 'delegates to the next middlex for non-POST'
  it 'calls the handler when receiving an avent'
  it 'calls the handler multiple times'
end
