require 'routemaster/cache'

module Routemaster::FaradayMiddleware
  class Caching

    def initialize(app, cache = Routemaster::Cache.new)
      @app = app
      @cache = cache
    end

    def call(env)
      return app.call(env) unless env.method == :get

      url, version, locale = url(env), version(env), locale(env)

      options = {}.tap do |o|
        o[:locale]  = locale if locale
        o[:version] = version if version
      end

      args = options.empty? ? [url] : [url, options]
      cache.with_caching(*args) do
        app.call(env)
      end
    end

    private

    attr_reader :cache, :app

    def url(request_env)
      request_env.url.to_s
    end

    VERSION_REGEX = /application\/json;v=(?<version>\S*)/.freeze

    def version(request_env)
      accept = request_env.request_headers['Accept']
      VERSION_REGEX.match(accept) { |match| match[:version] }
    end

    def locale(request_env)
      request_env.request_headers['Accept-Language']
    end
  end
end
