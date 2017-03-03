require 'spec_helper'
require 'hashie/mash'
require 'routemaster/responses/future_response'

describe Routemaster::Responses::FutureResponse do
  %i[status headers body].each do |method|
    it "passes through '#{method}'" do
      future = described_class.new { Hashie::Mash.new(method => 'foobar') }
      expect(future.public_send(method)).to eq('foobar')
    end
  end

  it 're-raises exceptions' do
    future = described_class.new { raise 'foobar' }

    expect { future.status }.to raise_error(RuntimeError, 'foobar')
  end
end
