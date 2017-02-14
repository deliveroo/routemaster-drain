require 'spec_helper'

require_relative '../../lib/routemaster/redis_broker'

describe Routemaster::RedisBroker do
  subject { Class.new(Routemaster::RedisBroker).instance }

  describe "#get" do
    let(:urls)   { ['redis://localhost/12'] }

    context "setting up a redis namespace" do
      let(:redis)           { instance_double(Redis, id: 1) }
      let(:redis_namespace) { instance_double(Redis::Namespace) }

      before do
        allow(Redis::Distributed).to receive(:new) { redis }
        allow(Redis::Namespace).to receive(:new) { redis_namespace }
      end

      it 'returns a namespaced redis connection' do
        expect(subject.get(:name, urls: urls)).to eq(redis_namespace)
      end

      it 'uses the url to initialise redis' do
        expect(Redis::Distributed).to receive(:new).with(urls)
        subject.get(:name, urls: urls)
      end

      it 'namespaces with rm by default' do
        expect(Redis::Namespace).to receive(:new).with('rm', redis: redis)
        subject.get(:name, urls: urls)
      end

      it 'can use a namespace based on the url' do
        expect(Redis::Namespace).to receive(:new).with('other', redis: redis)
        subject.get(:name, urls: ['redis://localhost/12/other'])
      end
    end

    context "when we are in the same process" do
      it 'is a single connection for each url' do
        expect(subject.get(:name, urls: urls)).to eql(subject.get(:name, urls: urls))
      end
    end

    context "when we have forked" do
      let!(:connection) { subject.get(:name, urls: urls) }

      it 'is a new connection for the newly forked process' do
        # this is tied to implementation, but tests a 'fork' well enough
        allow(Process).to receive(:pid) { -1 }
        expect(subject.get(:name, urls: urls)).to_not eql(connection)
      end
    end
  end
end
