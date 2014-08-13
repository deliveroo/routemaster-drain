require 'spec_helper'
require 'spec/support/write_expectation'
require 'routemaster/receiver'

describe Routemaster::Receiver do
  describe '#initialize' do
    let(:app) { double 'app' }

    it 'returns a ::Basic' do
      expect(described_class.new(app)).to be_a(Routemaster::Receiver::Basic)
    end

    it 'issues a warning' do
      expect { described_class.new(app) }.to write('deprecated').to(:error)
    end
  end
end

