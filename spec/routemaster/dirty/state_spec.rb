require 'spec_helper'
require 'spec/support/uses_redis'
require 'routemaster/dirty/state'

describe Routemaster::Dirty::State do
  uses_redis
  
  let(:argv) {[ 'https://example.com/1', 1234 ]}
  subject { described_class.new(*argv) }

  describe '#initialize' do
    it 'accepts url, exists flag, timestamp in order' do
      expect(subject.url).to eq('https://example.com/1')
      expect(subject.t).to eq(1234)
    end
  end

  describe '.get' do
    it 'uses different keys for different URLs' do
      keys = Set.new
      allow(redis).to receive(:get) { |key| keys.add(key) ; nil }
      described_class.get(redis, 'https://example.com/1')
      described_class.get(redis, 'https://example.com/2')
      expect(keys.size).to eq(2)
    end

    it 'return a null state when cache is empty' do
      state = described_class.get(redis, 'https://example.com/1')
      expect(state.url).to eq('https://example.com/1')
      expect(state.t).to eq(0)
    end
  end

  describe '#save' do
    it 'saves data that can be .get' do
      subject.save(redis, 1)
      loaded = described_class.get(redis, subject.url)
      expect(loaded).to eq(subject)
    end
  end
end
