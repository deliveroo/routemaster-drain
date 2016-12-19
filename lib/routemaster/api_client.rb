require 'base64'
require 'faraday'
require 'faraday_middleware'
require 'hashie'
require 'routemaster/config'
require 'routemaster/middleware/response_caching'
require 'routemaster/middleware/error_handling'
require 'routemaster/responses/future_response'

module Routemaster
  class APIClient
    def initialize(middlewares: [], listener: nil, response_class: nil)
      @listener = listener
      @middlewares = middlewares
      @response_class = response_class
    end

    # Performs a GET HTTP request for the `url`, with optional
    # query parameters (`params`) and additional headers (`headers`).
    #
    # @return an object that responds to `status` (integer), `headers` (hash),
    # and `body`. The body is a `Hashie::Mash` if the response was JSON, a
    # string otherwise.
    def get(url, params: {}, headers: {})
      host = URI.parse(url).host
      response_wrapper do
        connection.get(url, params, headers.merge(auth_header(host)))
      end
    end

    def post(url, body: {}, headers: {})
      host = URI.parse(url).host
      response_wrapper do
        connection.post do |req|
          req.url url
          req.headers = headers.merge(auth_header(host))
          req.body = body
        end
      end
    end

    def patch(url, body: {}, headers: {})
      host = URI.parse(url).host
      response_wrapper do
        connection.patch do |req|
          req.url url
          req.headers = headers.merge(auth_header(host))
          req.body = body
        end
      end
    end

    def fget(url, headers: {})
      Responses::FutureResponse.new { get(url, headers: headers) }
    end

    def discover(url)
      get(url)
    end

    private

    def response_wrapper(&block)
      response = block.call
      @response_class ? @response_class.new(response, client: self) : response
    end

    def connection
      @connection ||= Faraday.new do |f|
        f.request  :json
        f.request  :retry, max: 2, interval: 100e-3, backoff_factor: 2
        f.response :mashify
        f.response :json, content_type: /\bjson/
        f.use Routemaster::Middleware::ResponseCaching, listener: @listener
        f.adapter  :net_http_persistent
        f.use Routemaster::Middleware::ErrorHandling

        @middlewares.each do |middleware|
          f.use(*middleware)
        end

        f.options.timeout      = ENV.fetch('ROUTEMASTER_CACHE_TIMEOUT', 1).to_f
        f.options.open_timeout = ENV.fetch('ROUTEMASTER_CACHE_TIMEOUT', 1).to_f
        f.ssl.verify           = ENV.fetch('ROUTEMASTER_CACHE_VERIFY_SSL', 'false') == 'true'
      end
    end

    def auth_header(host)
      auth_string = Config.cache_auth.fetch(host, []).join(':')
      { 'Authorization' => "Basic #{Base64.strict_encode64(auth_string)}" }
    end
  end
end
