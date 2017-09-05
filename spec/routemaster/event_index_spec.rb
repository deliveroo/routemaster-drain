require 'routemaster/event_index'
require 'spec/support/uses_redis'

describe Routemaster::EventIndex do
  uses_redis

  let(:cache) { Routemaster::Config.cache_redis }
  let(:url) { 'https://example.com/widgets/1234' }
  subject { described_class.new(url, cache: cache) }

  describe '#increment' do
    it 'increases #current' do
      expect {
        subject.increment
      }.to change {
        subject.current
      }.from(0).to(1)
    end

    it 'leaves all keys with TTLs' do
      subject.increment
      cache.redis.nodes.each do |node|
        node.keys.each do |key|
          expect(node.ttl(key)).to be > 0
        end
      end
    end
  end
end
