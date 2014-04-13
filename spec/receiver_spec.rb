require 'spec_helper'
require 'spec/support/rack_test'
require 'routemaster/receiver'

describe Routemaster::Receiver do
  let(:handler) { double 'handler', on_events: nil }
  let(:app) { described_class.new(fake_app, options) }
  
  
  def perform
    post '/events', payload, 'CONTENT_TYPE' => 'application/json'
  end
  
  let(:options) {{
    path:     '/events',
    uuid:     'demo',
    handler:  handler
  }}

  class FakeApp
    def call(env)
      [501, {}, 'fake app']
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
    expect(last_response.status).to eq(204)
  end

  it 'fails without authentication' do
    perform
    expect(last_response.status).to eq(401)
  end

  it 'delegates to the next middleware for unknown paths' do
    post '/foobar'
    expect(last_response.status).to eq(501)
  end

  it 'delegates to the next middlex for non-POST' do
    get '/events'
    expect(last_response.status).to eq(501)
  end

  it 'calls the handler when receiving an avent' do
    authorize 'demo', 'x'
    expect(handler).to receive(:on_events).exactly(:once)
    perform
  end

  it 'calls the handler multiple times' do
    authorize 'demo', 'x'
    expect(handler).to receive(:on_events).exactly(3).times
    3.times { perform }
  end
end
