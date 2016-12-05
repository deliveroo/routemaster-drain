require 'faraday'
require 'faraday_middleware'
require 'hashie'
require 'routemaster/config'
require 'routemaster/middleware/caching'

module Routemaster
  class Fetcher
    DEFAULT_MIDDLEWARES = [[Routemaster::Middleware::Caching]]

    #
    # Usage:
    #
    # You can extend Fetcher with custom middlewares like:
    # Fetcher.new(middlewares: [[MyCustomMiddleWare, option1, option2]])
    #
    def initialize(middlewares: [])
      @middlewares = DEFAULT_MIDDLEWARES + middlewares
    end

    # Performs a GET HTTP request for the `url`, with optional
    # query parameters (`params`) and additional headers (`headers`).
    #
    # @return an object that responds to `status` (integer), `headers` (hash),
    # and `body`. The body is a `Hashie::Mash` if the response was JSON, a
    # string otherwise.
    def get(url, params:nil, headers:nil)
      host = URI.parse(url).host
      r = _connection.get(url, params, headers.merge(auth_header(host)))
      Hashie::Mash.new(status: r.status, headers: r.headers, body: r.body)
    end

    private

    def _connection
      @_connection ||= Faraday.new do |f|
        f.request  :retry, max: 2, interval: 100e-3, backoff_factor: 2
        f.response :mashify
        f.response :json, content_type: /\bjson/
        f.adapter  :net_http_persistent

        f.options.timeout      = ENV.fetch('ROUTEMASTER_CACHE_TIMEOUT', 1).to_f
        f.options.open_timeout = ENV.fetch('ROUTEMASTER_CACHE_TIMEOUT', 1).to_f
        f.ssl.verify           = ENV.fetch('ROUTEMASTER_CACHE_VERIFY_SSL', 'false') == 'true'

        @middlewares.each do |middleware|
          f.use(*middleware)
        end
      end
    end

    def auth_header(host)
      auth_string = Config.cache_auth.fetch(host, "").join(':')
      { 'Authorization' => "Basic #{Base64.strict_encode64(auth_string)}" }
    end
  end
end
