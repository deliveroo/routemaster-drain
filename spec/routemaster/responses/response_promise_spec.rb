require 'spec_helper'
require 'hashie/mash'
require 'routemaster/responses/response_promise'

describe Routemaster::Responses::ResponsePromise do
  %i[status headers body].each do |method|
    it "passes through '#{method}'" do
      future = described_class.new { Hashie::Mash.new(method => 'foobar') }
      expect(future.public_send(method)).to eq('foobar')
    end
  end

  it "is chainable" do
    passing_spy = spy('passing spy')
    future = described_class.new {}
    future.on_success { passing_spy.on_success }
    future.value
    expect(passing_spy).to have_received(:on_success)
  end

  it 're-raises exceptions' do
    future = described_class.new { raise 'foobar' }

    expect { future.status }.to raise_error(RuntimeError, 'foobar')
  end
end
