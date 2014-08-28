require 'spec_helper'
require 'spec/support/rack_test'
require 'spec/support/events'
require 'routemaster/middleware/filter'
require 'json'

describe Routemaster::Middleware::Filter do
  let(:terminator) { ErrorRackApp.new }
  let(:app) { described_class.new(terminator, **options) }
  
  let(:perform) do
    post '/whatever', '', 'routemaster.payload' => payload
  end

  describe '#call' do
    let(:filter) { double('filter') }
    let(:options) {{ filter:filter }}
    let(:payload) { [make_event(1)] }

    it 'calls the filter' do
      expect(filter).to receive(:run).with(payload)
      perform
    end

    it 'puts filtered events in the environment' do
      allow(filter).to receive(:run).with(payload).and_return(:foo)
      perform
      expect(terminator.last_env['routemaster.payload']).to eq(:foo)
    end
  end
end




