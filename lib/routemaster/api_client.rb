require 'base64'
require 'faraday'
require 'faraday_middleware'
require 'typhoeus'
# loading the Faraday adapter for Typhoeus requires a little dance:
require 'faraday/adapter/typhoeus'
require 'typhoeus/adapters/faraday'
require 'hashie'
require 'routemaster/config'
require 'routemaster/middleware/response_caching'
require 'routemaster/middleware/error_handling'
require 'routemaster/middleware/metrics'
require 'routemaster/responses/hateoas_response'
require 'routemaster/responses/hateoas_enumerable_response'
require 'routemaster/responses/future_response'
require 'routemaster/resources/rest_resource'

module Routemaster
  class APIClient
    def initialize(middlewares: [],
                   listener: nil,
                   response_class: nil,
                   metrics_client: nil,
                   source_peer: nil)
      @listener = listener
      @middlewares = middlewares
      @response_class = response_class
      @metrics_client = metrics_client
      @source_peer = source_peer

      connection # warm up connection so Faraday does all it's magical file loading in the main thread
    end

    # Performs a GET HTTP request for the `url`, with optional
    # query parameters (`params`) and additional headers (`headers`).
    #
    # @return an object that responds to `status` (integer), `headers` (hash),
    # and `body`. The body is a `Hashie::Mash` if the response was JSON, a
    # string otherwise.
    def get(url, params: {}, headers: {}, options: {})
      host = URI.parse(url).host
      enable_caching = options.fetch(:enable_caching, true)

      response_wrapper do
        request_headers = headers.
          merge(auth_header(host)).
          merge(response_cache_opt_headers(enable_caching))

        connection.get(url, params, request_headers)
      end
    end

    def fget(url, params: {}, headers: {})
      Responses::FutureResponse.new { get(url, params: {}, headers: {}) }
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

    def delete(url, headers: {})
      host = URI.parse(url).host
      response_wrapper do
        connection.delete do |req|
          req.url url
          req.headers = headers.merge(auth_header(host))
        end
      end
    end

    def discover(url)
      get(url)
    end

    def with_response(response_class, &block)
      @response_class = response_class
      result = block.call(self)
      @response_class = Responses::HateoasResponse
      result
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
        f.use Routemaster::Middleware::Metrics, client: @metrics_client, source_peer: @source_peer
        f.adapter :typhoeus
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

    def response_cache_opt_headers(value)
      { Routemaster::Middleware::ResponseCaching::RESPONSE_CACHING_OPT_HEADER => value.to_s }
    end
  end
end
