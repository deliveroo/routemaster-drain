require 'spec_helper'
require 'hashie/mash'
require 'routemaster/responses/response_promise'

describe Routemaster::Responses::ResponsePromise do
  %i[status headers body].each do |method|
    it "passes through '#{method}'" do
      promise = described_class.new { Hashie::Mash.new(method => 'foobar') }
      promise.execute
      expect(promise.public_send(method)).to eq('foobar')
    end
  end

  it "can have callbacks set" do
    passing_spy = spy('passing spy')
    promise = described_class.new { }
    success_promise = promise.on_success { passing_spy.on_success }
    promise.execute
    promise.value
    success_promise.value
    expect(passing_spy).to have_received(:on_success)
  end

  it 're-raises exceptions' do
    promise = described_class.new { raise 'foobar' }
    promise.execute
    expect { promise.status }.to raise_error(RuntimeError, 'foobar')
  end
end
