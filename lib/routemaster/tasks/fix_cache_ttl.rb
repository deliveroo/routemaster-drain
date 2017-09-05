require 'routemaster/cache_key'

module Routemaster
  module Tasks
    class FixCacheTTL
      def initialize(cache: Config.cache_redis, batch_size: 100)
        @cache = cache
        @batch_size = batch_size
      end

      def call
        pattern = "#{@cache.namespace}:#{CacheKey::PREFIX}*"
        _each_key_batch(pattern) do |node, keys|
          _fix_keys(node, keys)
        end
      end

      private

      def _each_key_batch(pattern)
        @cache.redis.nodes.each do |node|
          cursor = 0
          loop do
            cursor, keys = node.scan(cursor, count: @batch_size, match: pattern)
            yield node, keys
            break if cursor.to_i == 0
          end
        end
      end

      def _fix_keys(node, keys)
        ttls = node.pipelined do |p|
          keys.each { |k| p.ttl(k) }
        end

        node.pipelined do |p|
          keys.zip(ttls).each do |k,ttl|
            next unless ttl < 0
            p.expire(k, Config.cache_expiry)
          end
        end
      end
    end
  end
end
