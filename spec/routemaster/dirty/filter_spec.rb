require 'spec_helper'
require 'spec/support/uses_redis'
require 'routemaster/dirty/filter'

describe Routemaster::Dirty::Filter do
  uses_redis

  def make_url(idx) ; "https://example.com/#{idx}" ; end

  describe '#initialize' do
    it 'requires the redis: options' do
      expect { described_class.new }.to raise_error(KeyError)
      expect { described_class.new(redis: double) }.not_to raise_error
    end

    it 'accepts optional :expiry' do
      expect { described_class.new(redis: double, expiry: 10) }.not_to raise_error
    end
  end

  describe '#run' do
    let(:options) {{ redis:  redis }}
    subject { described_class.new(options) }

    let(:result) { subject.run(payload) }
    let(:payload) { [] }

    context 'blank slate' do
      %w(create delete update).each do |event|
        let(:url) { make_url(1) }

        it "keeps a '#{event}' event" do
          event = { 'topic' => 'stuff', 'type' => event, 'url' => url, 't' => 1234 }
          payload.push event
          expect(result).to include(event)
        end
      end
    end

    context 'with a prior event' do
      let(:url) { make_url(1) }
      let(:prior_event) {{ 'topic' => 'stuff', 'type' => 'update', 'url' => url, 't' => 1234 }}

      before { payload.push prior_event }

      it "keeps a newer event" do
        newer_event = { 'topic' => 'stuff', 'type' => 'update', 'url' => url, 't' => 1235 }
        payload.push newer_event
        expect(result).to eq([newer_event])
      end

      it "does keep an older event" do
        older_event = { 'topic' => 'stuff', 'type' => 'update', 'url' => url, 't' => 1233 }
        payload.push older_event
        expect(result).to eq([prior_event])
      end
    end

    context 'with a prior state' do
      let(:url) { make_url(1) }
      let(:prior_event) {{ 'topic' => 'stuff', 'type' => 'update', 'url' => url, 't' => 1234 }}

      before { subject.run([prior_event]) }

      it "keeps a newer event" do
        newer_event = { 'topic' => 'stuff', 'type' => 'update', 'url' => url, 't' => 1235 }
        payload.push newer_event
        expect(result).to eq([newer_event])
      end

      it "does not keep an older event" do
        older_event = { 'topic' => 'stuff', 'type' => 'update', 'url' => url, 't' => 1233 }
        payload.push older_event
        expect(result).to be_empty
      end
    end
  end
end
