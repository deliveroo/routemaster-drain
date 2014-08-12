require 'spec_helper'
require 'spec/support/uses_redis'
require 'routemaster/dirty/listener'

describe Routemaster::Dirty::Listener do
  uses_redis

  def make_url(idx) ; "https://example.com/#{idx}" ; end

  describe '#initialize' do
    it 'requires the redis: options' do
      expect { described_class.new }.to raise_error(KeyError)
      expect { described_class.new(redis: double) }.not_to raise_error
    end

    it 'accepts optional :topics' do
      expect { described_class.new(redis: double, topics: []) }.not_to raise_error
    end

    it 'accepts optional :expiry' do
      expect { described_class.new(redis: double, expiry: 10) }.not_to raise_error
    end
  end

  describe '#on_events_received' do
    let(:listener) { double 'listener' }
    let(:options) {{ redis:  redis }}
    subject { described_class.new(options) }

    let(:perform) { subject.on_events_received(payload) }
    let(:payload) { [] }

    before { subject.subscribe(listener, prefix: true) }

    context 'blank slate' do
      %w(create delete update).each do |event|
        let(:url) { make_url(1) }

        it "broadcasts on '#{event}'" do
          payload.push('topic' => 'stuff', 'type' => event, 'url' => url, 't' => 1234)
          expect(listener).to receive(:on_entity_changed).with(url)
          perform
        end
      end
    end

    context 'prior event' do
      let(:url) { make_url(1) }

      before do
        payload.push('topic' => 'stuff', 'type' => 'update', 'url' => url, 't' => 1234)
      end

      it "broadcast on newer event" do
        payload.push('topic' => 'stuff', 'type' => 'update', 'url' => url, 't' => 1235)
        expect(listener).to receive(:on_entity_changed).with(url).exactly(:twice)
        perform
      end

      it "does not broadcast on older event" do
        payload.push('topic' => 'stuff', 'type' => 'update', 'url' => url, 't' => 1233)
        expect(listener).to receive(:on_entity_changed).with(url).exactly(:once)
        perform
      end
    end
  end
end
