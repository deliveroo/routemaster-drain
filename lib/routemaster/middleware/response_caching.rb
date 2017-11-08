require 'wisper'
require 'routemaster/event_index'
require 'routemaster/cache_key'
require 'routemaster/lua_script'

module Routemaster
  module Middleware
    class ResponseCaching
      BODY_FIELD_TEMPLATE = 'v:{version},l:{locale},body'.freeze
      HEADERS_FIELD_TEMPLATE = 'v:{version},l:{locale},headers'.freeze
      VERSION_REGEX = /application\/json;v=(?<version>\S*)/
      RESPONSE_CACHING_OPT_HEADER = 'X-routemaster_drain.opt_cache'.freeze

      def initialize(app, cache: Config.cache_redis, listener: nil)
        @app = app
        @cache = cache
        @expiry = Config.cache_expiry
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
            if Config.logger.debug?
              Config.logger.debug("DRAIN: Saving #{url(env)} with a event index of #{event_index}")
            end

            namespaced_key = "#{@cache.namespace}:#{cache_key(env)}"
            script = LuaScript.new('cache_service_response', @cache.redis.node_for(namespaced_key))
            script.run(
              [namespaced_key],
              [
                body_cache_field(env), response.body,
                headers_cache_field(env), Marshal.dump(response.headers),
                :most_recent_index, event_index,
                @expiry
              ]
            )

            @listener._publish(:cache_miss, url(env)) if @listener
          end
        end
      end

      def fetch_from_cache(env)
        return nil unless cache_enabled?(env)
        body, headers, most_recent_index, current_index = currently_cached_content(env)

        unless most_recent_index.to_i == current_index.to_i && body && headers
          Config.logger.debug("DRAIN: Cache miss #{url(env)} - index_recent: #{most_recent_index.to_i}") if Config.logger.debug?
          return nil
        end

        Config.logger.debug("DRAIN: Cache hit #{url(env)} - index_recent: #{most_recent_index.to_i}") if Config.logger.debug?
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
        (env.request_headers['Accept'] || '')[VERSION_REGEX, 1]
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

      def currently_cached_content(env)
        @cache.hmget(cache_key(env),
                     body_cache_field(env),
                     headers_cache_field(env),
                     :most_recent_index,
                     :current_index)
      end
    end
  end
end
