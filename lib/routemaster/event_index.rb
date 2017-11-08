require 'routemaster/cache_key'
require 'routemaster/lua_script'
module Routemaster
  class EventIndex
    def initialize(url, cache: Config.cache_redis)
      @url = url
      @cache = cache
    end

    def increment
      LuaScript.new('increment_and_expire_h', @cache)
                .run([_key],['current_index', Config.cache_expiry])
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
