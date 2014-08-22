require 'spec_helper'
require 'spec/support/rack_test'
require 'spec/support/events'
require 'routemaster/middleware/filter'
require 'json'

describe Routemaster::Middleware::Filter do
  class RecordEnvApp
    def call(env)
      @last_env = env
      [204, {}, []]
    end

    def payload
      @last_env['routemaster.payload']
    end
  end

  let(:app) { described_class.new(RecordEnvApp.new, options) }
  
  def perform(payload = nil)
    post '/whatever', '', 'routemaster.payload' => payload
  end

  describe '#initialize' do
    it 'requires the :redis option'
  end

  describe '#call' do
    let(:filter) { double('filter') }
    let(:options) {{ redis: double('redis') }}

    before do
      allow(Routemaster::Dirty::Filter).to receive(:new).and_return(filter)
    end

    it 'calls the filter'
    it 'returns the filtered events'
  end
end




