require 'routemaster/fetcher'
require 'thread/pool'
require 'thread/future'
require 'singleton'
require 'delegate'
require 'json'
require 'wisper'

module Routemaster
  # Caches GET requests.
  #
  # Emits `cache_bust`, `cache_hit`, and `cache_miss` events.
  #
  # The requests themselves are handled by {Fetcher}.
  # Note that `Cache-Control` headers are intentionally ignored, as it is
  # assumed one will call {#bust} when the cache becomes stale.
  #
  # This is for instance done automatically by {Middleware::Caching}
  # upon receiving events from Routemaster.
  #
  class Cache
    include Wisper::Publisher

    # A pool of threads, used for parallal/future request processing.
    class Pool < SimpleDelegator
      include Singleton

      def initialize
        Thread.pool(5, 20).tap do |p|
          # TODO: configurable pool size and trim timeout?
          p.auto_trim!
          p.idle_trim! 10 # 10 seconds
          super p
        end
      end
    end

    # Wraps a future response, so it quacks exactly like an ordinary response.
    class FutureResponse
      extend Forwardable
      
      def initialize(&block)
        @future = Pool.instance.future(&block)
      end

      delegate :value => :@future
      delegate %i(status headers body) => :value
    end

    class Response < Hashie::Mash
    end


    def initialize(redis:nil)
      @redis   = redis || Config.cache_redis
      @expiry  = Config.cache_expiry
    end

    # Bust the cache for a given URL
    def bust(url)
      @redis.del(url)
      publish(:cache_bust, url)
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
    def get(url, version:nil, locale:nil)
      key   = "cache:#{url}"
      field = "v:#{version},l:#{locale}"

      # check cache
      if payload = @redis.hget(key, field)
        publish(:cache_hit, url)
        return Response.new(JSON.parse(payload))
      end

      # fetch data
      headers = {
        'Accept' => version ?
          "application/json;v=#{version}" :
          "application/json"
      }
      headers['Accept-Language'] = locale if locale
      response = Fetcher.get(url, headers: headers)

      # store in redis
      @redis.hset(key, field, response.to_json)
      @redis.expire(key, @expiry)

      publish(:cache_miss, url)
      Response.new(response)
    end

    # Like {get}, but schedules any request in the background using a thread
    # pool. Handy to issue lots of requests in parallel.
    #
    # @return [FutureResponse], which responds to `status`, `headers`, and `body`
    # like [Response].
    def fget(*args)
      FutureResponse.new { get(*args) }
    end
  end
end
