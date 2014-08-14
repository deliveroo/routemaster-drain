require 'spec_helper'
require 'routemaster/receiver'

describe Routemaster::Receiver do
  describe '#initialize' do
    let(:app) { double 'app' }

    it 'returns a ::Basic' do
      expect(described_class.new(app)).to be_a(Routemaster::Receiver::Basic)
    end

    it 'issues a warning' do
      expect(described_class).to receive(:warn).with(/deprecated/)
      described_class.new(app)
    end
  end
end

