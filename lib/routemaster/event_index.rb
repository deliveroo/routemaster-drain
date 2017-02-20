require 'routemaster/cache_keys'
module Routemaster
  class EventIndex
    attr_reader :url, :cache

    def initialize(url, cache: Config.cache_redis)
      @url = url
      @cache = cache
    end

    def key
      CacheKeys.new(url).url_key
    end

    def increment
      cache.hincrby(key, 'current_index', 1).to_i
    end

    def current
      (cache.hget(key, 'current_index') || 0).to_i
    end
  end
end
