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
      let(:options){ {} }
      it "passes all to the terminator"  do
        perform
        expect(terminator.last_env['routemaster.payload']).to eq payload
      end
    end

    context "if a 'stuff' syphon is defined" do
      let(:syphon_double){
        double(new: syphon_instance)
      }
      let(:syphon_instance){
        double(call: nil)
      }
      let(:options){ { 'stuff' => syphon_double } }

      it "calls the syphon with the event" do
        perform
        expect(syphon_double).to have_received(:new).with(payload[0])
        expect(syphon_instance).to have_received(:call)
      end

      it "passes 'notstuff' to the terminator"  do
        perform
        expect(terminator.last_env['routemaster.payload']).to eq [payload[1]]
      end
    end
  end
end
