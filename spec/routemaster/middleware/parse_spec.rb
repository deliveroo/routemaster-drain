# test for bad MIME
# test for bad JSON
# test for correct JSON with bad format

require 'spec_helper'
require 'spec/support/rack_test'
require 'spec/support/events'
require 'routemaster/middleware/parse'
# require 'json'

describe Routemaster::Middleware::Parse do
  let(:terminator) { ErrorRackApp.new }
  let(:app) { described_class.new(terminator) }
  let(:payload) { [make_event(1), make_event(2)].to_json }
  let(:env) {{ 'CONTENT_TYPE' => 'application/json' }}
  let(:perform) { post '/whatever', payload, env }

  describe '#call' do
    context 'correct MIME and JSON' do
      it 'yields to next middleware' do
        perform
        expect(last_response.status).to eq(501)
      end

      it 'passes data in env' do
        perform
        expect(terminator.last_env['routemaster.payload']).to eq([make_event(1), make_event(2)])
      end
    end

    context 'with bad MIME' do
      let(:env) {{ 'CONTENT_TYPE' => 'text/plain' }}
      it 'returns 415' do
        perform
        expect(last_response.status).to eq(415)
      end

      it 'does not pass any data' do
        expect(terminator.last_env).not_to include('routemaster.payload')
      end
    end

    context 'bad JSON' do
      let(:payload) { '[{ "key": "gibberish' }

      it 'returns 400' do
        perform
        expect(last_response.status).to eq(400)
      end

      it 'does not pass any data' do
        expect(terminator.last_env).not_to include('routemaster.payload')
      end
    end

    # context 'no body'
    context 'correct JSON, bad format' do
      let(:payload) { '[{ "type": "noop", "topic":"widgets", "t":123 }]' }

      it 'returns 400' do
        perform
        expect(last_response.status).to eq(400)
      end

      it 'does not pass any data' do
        expect(terminator.last_env).not_to include('routemaster.payload')
      end
    end

  end
end



