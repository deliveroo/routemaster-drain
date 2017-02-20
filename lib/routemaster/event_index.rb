require 'routemaster/cache_key'
module Routemaster
  class EventIndex
    attr_reader :url, :cache

    def initialize(url, cache: Config.cache_redis)
      @url = url
      @cache = cache
    end

    def increment
      cache.hincrby(CacheKey.url_key(url), 'current_index', 1).to_i
    end

    def current
      (cache.hget(CacheKey.url_key(url), 'current_index') || 0).to_i
    end
  end
end
