require 'spec_helper'

require_relative '../../lib/routemaster/redis_broker'

describe Routemaster::RedisBroker do
  subject { Class.new(Routemaster::RedisBroker).instance }

  describe "#get" do
    let(:url)   { 'redis://localhost/12' }

    context "setting up a redis namespace" do
      let(:redis)           { instance_double(Redis) }
      let(:redis_namespace) { instance_double(Redis::Namespace) }

      before do
        allow(Redis).to receive(:new) { redis }
        allow(Redis::Namespace).to receive(:new) { redis_namespace }
      end

      it 'returns a namespaced redis connection' do
        expect(subject.get(url)).to eq(redis_namespace)
      end

      it 'uses the url to initialise redis' do
        expect(Redis).to receive(:new).with(url: url)
        subject.get(url)
      end

      it 'namespaces with rm by default' do
        expect(Redis::Namespace).to receive(:new).with('rm', redis: redis)
        subject.get(url)
      end

      it 'can use a namespace based on the url' do
        expect(Redis::Namespace).to receive(:new).with('other', redis: redis)
        subject.get('redis://localhost/12/other')
      end
    end

    context "when we are in the same process" do
      it 'is a single connection for each url' do
        expect(subject.get(url)).to eql(subject.get(url))
      end
    end

    context "when we have forked" do
      let!(:connection) { subject.get(url) }

      it 'is a new connection for the newly forked process' do
        # this is tied to implementation, but tests a 'fork' well enough
        allow(Process).to receive(:pid) { -1 }
        expect(subject.get(url)).to_not eql(connection)
      end
    end
  end
end
