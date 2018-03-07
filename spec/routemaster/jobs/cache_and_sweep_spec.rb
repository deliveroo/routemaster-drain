require 'routemaster/jobs/cache_and_sweep'
require 'routemaster/dirty/map'
require 'spec_helper'

RSpec.describe Routemaster::Jobs::CacheAndSweep do
  let(:url)        { 'https://example.com/foo' }
  let(:sample_env) { OpenStruct.new(url: url, status: 200) }

  subject { described_class.new }

  context 'when there is an ResourceNotFound error' do
    before do
      allow_any_instance_of(Routemaster::Cache)
        .to receive(:get)
        .and_raise(Routemaster::Errors::ResourceNotFound.new(sample_env))
    end

    it 'does not bubble up the error' do
      expect { subject.perform(url) }.to_not raise_error
    end

    it 'sweeps the resource from the dirty map' do
      expect_any_instance_of(Routemaster::Dirty::Map)
        .to receive(:sweep_one)
        .with(url) { |&block| expect(block.call).to eq true }

      subject.perform(url)
    end

    it 'busts the cached version of the resource' do
      expect_any_instance_of(Routemaster::Cache)
        .to receive(:bust)
        .with(url)

      subject.perform(url)
    end
  end

  context 'when there is any other error' do
    before do
      expect_any_instance_of(Routemaster::Cache).to receive(:get).and_raise("boom")
    end

    it 'does bubble up the error' do
      expect { subject.perform('url') }.to raise_error("boom")
    end
  end
end
