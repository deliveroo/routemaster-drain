module Routemaster
  class EventIndex
    attr_reader :url, :store

    def initialize(url, store: Config.cache_redis)
      @url = url
      @store = store
    end

    def increment
      store.incr("event_index:#{url}").to_i
    end

    def current
      (store.get("event_index:#{url}") || 0).to_i
    end
  end
end
