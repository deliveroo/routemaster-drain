require 'spec_helper'
require 'spec/support/uses_redis'
require 'routemaster/dirty/map'

describe Routemaster::Dirty::Map do
  uses_redis

  subject { described_class.new(redis: redis) }

  def url(idx) ; "https://example.com/#{idx}" ; end

  def mark_urls(count)
    1.upto(count) do |idx|
      subject.mark(url(idx))
    end
  end

  describe '#mark' do
    it 'passes' do
      expect { subject.mark(url(1)) }.not_to raise_error
    end

    it 'returns true if marking for the first time' do
      expect(subject.mark(url(1))).to eq(true)
    end

    it 'returns false if re-marking' do
      subject.mark(url(1))
      expect(subject.mark(url(1))).to eq(false)
    end
  
    context 'with a listener' do
      let(:handler) { double }
      before { subject.subscribe(handler, prefix: true) }

      
      it 'broadcasts :dirty_entity on new mark' do
        expect(handler).to receive(:on_dirty_entity).exactly(10).times
        mark_urls(10)
      end

      it 'does not broadcast on re-marks' do
        mark_urls(5)
        expect(handler).to receive(:on_dirty_entity).exactly(5).times
        mark_urls(10)
      end
    end
  end
  
  describe '#sweep' do
    it 'does not yield with no marks' do
      expect { |b| subject.sweep(&b) }.not_to yield_control
    end

    it 'yields marked URLs' do
      mark_urls(3)
      expect { |b| subject.sweep(&b) }.to yield_control.exactly(3).times
    end

    it 'does not yield if called again' do
      mark_urls(3)
      subject.sweep { |url| true }
      expect { |b| subject.sweep(&b) }.not_to yield_control
    end

    it 'honours "next"' do
      mark_urls(10)
      subject.sweep { |url| next if url =~ /3/ ; true }
      expect { |b| subject.sweep(&b) }.to yield_control.exactly(1).times
    end

    it 'yields the same URL again if the block returns falsy' do
      mark_urls(10)
      subject.sweep { |url| url =~ /7/ ? false : true }
      expect { |b| subject.sweep(&b) }.to yield_with_args(/7/)
    end

    it 'yields again if the block fails' do
      mark_urls(1)
      expect {
        subject.sweep { |url| raise }
      }.to raise_error(RuntimeError)
      expect { |b| subject.sweep(&b) }.to yield_control.exactly(1).times
    end
  end

  describe '#sweep_one' do
    it 'takes one URL' do
      mark_urls(3)
      expect { |b| subject.sweep_one(url(1), &b) }.to yield_control.exactly(:once)
    end

    it 'processes exactly one URL' do
      mark_urls(3)
      subject.sweep_one(url(1)) { true }
      expect(subject.count).to eq(2)
    end

    it 'does not sweep if block returns falsy' do
      mark_urls(3)
      subject.sweep_one(url(1)) { nil }
      expect(subject.count).to eq(3)
    end
  end

  describe '#count' do
    it 'is 0 by default' do
      expect(subject.count).to eq(0)
    end

    it 'increases when marking' do
      expect { mark_urls(10) }.to change { subject.count }.by(10)
    end

    it 'decreases when sweeping' do
      mark_urls(10)
      limit = 4
      subject.sweep { |url| (limit -= 1) < 0 ? false : true }
      expect(subject.count).to eq(6)
    end
  end
end
