require 'routemaster/jobs/cache_and_sweep'
require 'spec_helper'

RSpec.describe Routemaster::Jobs::CacheAndSweep do
  subject { described_class.new }

  context 'when there is an ResourceNotFound error' do
    before do
      expect_any_instance_of(Routemaster::Cache).to receive(:get).and_raise(Routemaster::Errors::ResourceNotFound.new(""))
    end

    it 'does not bubble up the error' do
      expect { subject.perform('url') }.to_not raise_error
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
