require 'routemaster/api_client'
require 'routemaster/cache_keys'
require 'wisper'

module Routemaster
  # Caches GET requests.
  #
  # Emits `cache_bust`, `cache_hit`, and `cache_miss` events.
  #
  # The requests themselves are handled by {APIClient}.
  # Note that `Cache-Control` headers are intentionally ignored, as it is
  # assumed one will call {#bust} when the cache becomes stale.
  #
  # This is for instance done automatically by {Middleware::Cache}
  # upon receiving events from Routemaster.
  #
  class Cache
    include Wisper::Publisher

    def initialize(redis: nil, client: nil)
      @redis  = redis || Config.cache_redis
      @client = client || APIClient.new(listener: self)
    end

    # Bust the cache for a given URL
    def bust(url)
      @redis.del(Routemaster::CacheKeys.new(url).url_key)
      _publish(:cache_bust, url)
    end

    # This is because wisper makes broadcasting methods private
    def _publish(event, url)
      publish(event, url)
    end

    # Get the response from a URL, from the cache if possible.
    # Stores to the cache on misses.
    #
    # Different versions and locales are stored separately in the cache.
    #
    # @param version [Integer] The version to pass in headers, as `Accept: application/json;v=2`
    # @param locale [String] The language to request in the `Accept-Language`
    # header.
    #
    # @return [Response], which responds to `status`, `headers`, and `body`.
    def get(url, version: nil, locale: nil)
      @client.get(url, headers: headers(version: version, locale: locale))
    end

    # Like {#get}, but schedules any request in the background using a thread
    # pool. Handy to issue lots of requests in parallel.
    #
    # @return [FutureResponse], which responds to `status`, `headers`, and `body`
    # like [Response].
    def fget(url, version: nil, locale: nil)
      @client.fget(url, headers: headers(version: version, locale: locale))
    end

    private

    def headers(version: nil, locale: nil)
      @headers ||= {}.tap do |hash|
        hash['Accept'] = version ? "application/json;v=#{version}" : "application/json"
        hash['Accept-Language'] = locale if locale
      end
    end
  end
end
