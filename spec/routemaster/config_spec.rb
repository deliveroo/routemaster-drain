require 'routemaster/config'

RSpec.describe Routemaster::Config do
  describe '.cache_expiry' do
    subject { described_class.cache_expiry }

    context 'when using the default' do
      it 'should be 90 days' do
        should eq 86_400 * 90
      end
    end

    context 'when overridden with ROUTEMASTER_CACHE_EXPIRY' do
      before { ENV['ROUTEMASTER_CACHE_EXPIRY'] = '123456' }
      after  { ENV['ROUTEMASTER_CACHE_EXPIRY'] = nil }

      it 'should be the configured value' do
        should eq 123456
      end
    end
  end
end
