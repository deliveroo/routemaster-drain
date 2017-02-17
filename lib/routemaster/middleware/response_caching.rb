require 'wisper'
require 'routemaster/event_index'

module Routemaster
  module Middleware
    class ResponseCaching
      KEY_TEMPLATE = 'cache:{url}'
      BODY_FIELD_TEMPLATE = 'v:{version},l:{locale},body'
      HEADERS_FIELD_TEMPLATE = 'v:{version},l:{locale},headers'
      VERSION_REGEX = /application\/json;v=(?<version>\S*)/.freeze
      RESPONSE_CACHING_OPT_HEADER = 'X-routemaster_drain.opt_cache'.freeze

      def initialize(app, cache: Config.cache_redis, listener: nil)
        @app = app
        @cache = cache
        @expiry  = Config.cache_expiry
        @listener = listener
      end

      def call(env)
        @cache.del(cache_key(env)) if %i(patch delete).include?(env.method)
        return @app.call(env) if env.method != :get
        @event_index = Routemaster::EventIndex.new(url(env)).current
        fetch_from_cache(env) || fetch_from_service(env)
      end

      private

      def fetch_from_service(env)
        @app.call(env).on_complete do |response_env|
          response = response_env.response

          if response.success? && cache_enabled?(env)
            namespaced_key = "#{@cache.namespace}:#{cache_key(env)}"
            @cache.redis.node_for(namespaced_key).multi do |node|
              node.hset(namespaced_key, body_cache_field(env), response.body)
              node.hset(namespaced_key, headers_cache_field(env), Marshal.dump(response.headers))
              node.hset(namespaced_key, :event_index, @event_index)
              node.expire(namespaced_key, @expiry)
            end

            @listener._publish(:cache_miss, url(env)) if @listener
          end
        end
      end

      def fetch_from_cache(env)
        return nil unless cache_enabled?(env)
        body = @cache.hget(cache_key(env), body_cache_field(env))
        headers = @cache.hget(cache_key(env), headers_cache_field(env))
        event_index =  @cache.hget(cache_key(env), :event_index)

        return nil unless event_index.to_i == @event_index && body && headers


        @listener._publish(:cache_hit, url(env)) if @listener

        Faraday::Response.new(status: 200,
                              body: body,
                              response_headers: Marshal.load(headers),
                              request: {})

      end

      def body_cache_field(env)
        BODY_FIELD_TEMPLATE
          .gsub('{version}', version(env).to_s)
          .gsub('{locale}', locale(env).to_s)
      end

      def headers_cache_field(env)
        HEADERS_FIELD_TEMPLATE
          .gsub('{version}', version(env).to_s)
          .gsub('{locale}', locale(env).to_s)
      end

      def cache_key(env)
        KEY_TEMPLATE.gsub('{url}', url(env))
      end

      def url(env)
        env.url.to_s
      end

      def version(env)
        (env.request_headers['Accept'] || "")[VERSION_REGEX, 1]
      end

      def locale(env)
        env.request_headers['Accept-Language']
      end

      def cache_enabled?(env)
        env.request_headers[RESPONSE_CACHING_OPT_HEADER].to_s == 'true'
      end
    end
  end
end
