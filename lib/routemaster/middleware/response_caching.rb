require 'wisper'
require 'routemaster/event_index'
require 'routemaster/cache_key'

module Routemaster
  module Middleware
    class ResponseCaching
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
        fetch_from_cache(env) || fetch_from_service(env, event_index(env))
      end

      private

      def fetch_from_service(env, event_index)
        @app.call(env).on_complete do |response_env|
          response = response_env.response

          if response.success? && cache_enabled?(env)
            namespaced_key = "#{@cache.namespace}:#{cache_key(env)}"
            @cache.redis.node_for(namespaced_key).multi do |node|
             node.hmset(namespaced_key,
                        body_cache_field(env), response.body,
                        headers_cache_field(env), Marshal.dump(response.headers),
                        :most_recent_index, event_index)
              node.expire(namespaced_key, @expiry)
            end

            @listener._publish(:cache_miss, url(env)) if @listener
          end
        end
      end

      def fetch_from_cache(env)
        return nil unless cache_enabled?(env)
        body, headers, most_recent_index, current_index = @cache.hmget(cache_key(env),
                                                                       body_cache_field(env),
                                                                       headers_cache_field(env),
                                                                       :most_recent_index,
                                                                       :current_index)

        return nil unless most_recent_index.to_i == current_index.to_i && body && headers

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
        CacheKey.url_key(url(env))
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

      def event_index(env)
        Routemaster::EventIndex.new(url(env)).current
      end
    end
  end
end
