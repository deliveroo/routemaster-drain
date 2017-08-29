require 'spec_helper'
require 'spec/support/rack_test'
require 'spec/support/events'
require 'routemaster/middleware/siphon'
require 'json'

describe Routemaster::Middleware::Siphon do
  let(:terminator) { ErrorRackApp.new }
  let(:app) { described_class.new(terminator, options) }

  let(:perform) do
    post '/whatever', '', 'routemaster.payload' => payload
  end

  describe '#call' do

    let(:options) { { filter:filter } }
    let(:payload) { [ make_event(1), make_event(1).merge({'topic' => 'notstuff'})] }

    context "if no siphon is defined" do
      let(:options) { {} }

      it "passes all to the terminator"  do
        perform
        expect(terminator.last_env['routemaster.payload']).to eq payload
      end
    end

    context "if a 'stuff' siphon is defined" do
      let(:siphon_double) { double(new: siphon_instance) }
      let(:siphon_instance) { double(call: nil) }
      let(:options) { { siphon_events: { 'stuff' => siphon_double } } }

      it "calls the siphon with the event" do
        perform
        expect(siphon_double).to have_received(:new).with(payload[0])
        expect(siphon_instance).to have_received(:call)
      end

      context "if an instance is defined as siphon" do
        let(:options) { { siphon_events: { 'stuff' => siphon_instance } } }

        it "calls the siphon :call method passing in event" do
          perform
          expect(siphon_instance).to have_received(:call).with(payload[0])
        end
      end

      it "passes 'notstuff' to the terminator"  do
        perform
        expect(terminator.last_env['routemaster.payload']).to eq [payload[1]]
      end
    end
  end
end
