require 'routemaster/cache'

module Routemaster::FaradayMiddleware
  class Caching

    def initialize(app, cache = Routemaster::Cache.new)
      @app = app
      @cache = cache
    end

    def call(env)
      return app.call(env) unless env.method == :get

      url = url(env)
      version = version(env)
      locale = locale(env)

      options = {}.tap do |o|
        o[:locale]  = locale if locale
        o[:version] = version if version
      end

      args = options.empty? ? [url] : [url, options]
      serialized_response = cache.fetch(*args) do
        serialize(app.call(env))
      end

      deserialize(serialized_response, env)
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

    def serialize(faraday_response)
      {
        status: faraday_response.status,
        headers: faraday_response.headers,
        body: faraday_response.body
      }
    end

    def deserialize(serialized_response, env)
      serialized_response[:response_headers] = serialized_response.delete :headers
      env.update(serialized_response)
      Faraday::Response.new(env)
    end
  end
end
