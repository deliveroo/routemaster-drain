require 'routemaster/tasks/fix_cache_ttl'
require 'spec/support/uses_redis'

describe Routemaster::Tasks::FixCacheTTL do
  uses_redis

  let(:cache) { Routemaster::Config.cache_redis }
  subject { described_class.new(cache: cache, batch_size: 5) }

  before do
    # add keys without a TTL, that aren't cache keys
    @ignored_keys = (1..20).map { |n| "fubar:#{n}".tap { |k| cache.set(k, n) } }

    # add cache keys with a pre-existing TTL
    @good_keys = (1..20).map { |n| "cache:good-#{n}".tap { |k| cache.set(k, n, ex: n + 1_000) } }
    
    # add cache keys without a TTL
    @bad_keys = (1..20).map { |n| "cache:bad-#{n}".tap { |k| cache.set("cache:bad-#{n}", n) } }
  end

  it 'leaves non-cache keys alone' do
    subject.call
    @ignored_keys.each { |k|
      expect(cache.ttl(k)).to eq -1
    }
  end

  it 'adds a TTL to broken cache keys' do
    subject.call
    @bad_keys.each { |k|
      expect(cache.ttl(k)).to be > 100_000
    }
  end

  it 'leaves the TTL of good cache keys alone' do
    subject.call
    @good_keys.each { |k|
      expect(0..2_000).to include cache.ttl(k)
    }
  end
end
