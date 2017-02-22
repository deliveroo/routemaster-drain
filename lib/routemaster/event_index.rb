require 'routemaster/cache_key'
module Routemaster
  class EventIndex
    attr_reader :url, :cache

    def initialize(url, cache: Config.cache_redis)
      @url = url
      @cache = cache
    end

    def increment
      i = cache.hincrby(CacheKey.url_key(url), 'current_index', 1).to_i
      Config.logger.debug("DRAIN: Increment #{@url} to #{i}") if Config.logger.debug?
      i
    end

    def current
      (cache.hget(CacheKey.url_key(url), 'current_index') || 0).to_i
    end
  end
end
