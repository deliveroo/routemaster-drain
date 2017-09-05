require 'routemaster/cache_key'
module Routemaster
  class EventIndex
    def initialize(url, cache: Config.cache_redis)
      @url = url
      @cache = cache
    end

    def increment
      _node do |cache, key|
        cache.multi do |m|
          m.hincrby(key, 'current_index', 1)
          m.expire(key, Config.cache_expiry)
        end
      end
      self
    end

    def current
      (@cache.hget(_key, 'current_index') || 0).to_i
    end

    private

    def _node
      namespaced_key = "#{@cache.namespace}:#{_key}"
      yield @cache.redis.node_for(namespaced_key), namespaced_key
    end

    def _key
      @_key ||= CacheKey.url_key(@url)
    end
  end
end
