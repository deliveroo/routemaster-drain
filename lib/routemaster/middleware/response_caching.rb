require 'wisper'

module Routemaster
  module Middleware
    class ResponseCaching
      KEY_TEMPLATE = 'cache:{url}'
      BODY_FIELD_TEMPLATE = 'v:{version},l:{locale},body'
      HEADERS_FIELD_TEMPLATE = 'v:{version},l:{locale},headers'
      VERSION_REGEX = /application\/json;v=(?<version>\S*)/.freeze

      def initialize(app, cache: Config.cache_redis, listener: nil)
        @app = app
        @cache = cache
        @expiry  = Config.cache_expiry
        @listener = listener
      end

      def call(env)
        return @app.call(env) unless env.method == :get

        fetch_from_cache(env) || fetch_from_service(env)
      end

      private

      def fetch_from_service(env)
        @app.call(env).on_complete do |response_env|
          response = response_env.response

          if response.success?
            @cache.multi do |multi|
              multi.hset(cache_key(env), body_cache_field(env), response.body)
              multi.hset(cache_key(env), headers_cache_field(env), Marshal.dump(response.headers))
              multi.expire(cache_key(env), @expiry)
            end
            @listener._publish(:cache_miss, url(env)) if @listener
          end
        end
      end

      def fetch_from_cache(env)
        body = @cache.hget(cache_key(env), body_cache_field(env))
        headers = @cache.hget(cache_key(env), headers_cache_field(env))

        if body && headers
          @listener._publish(:cache_hit, url(env)) if @listener
          Faraday::Response.new(status: 200,
                                body: body,
                                response_headers: Marshal.load(headers),
                                request: {})
        end
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
    end
  end
end
