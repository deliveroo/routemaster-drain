require 'base64'
require 'faraday'
require 'faraday_middleware'
require 'typhoeus'
require 'routemaster/config'
require 'routemaster/middleware/response_caching'
require 'routemaster/middleware/error_handling'
require 'routemaster/middleware/metrics'
require 'routemaster/responses/response_promise'
require 'routemaster/api_client_circuit'

# This is not a direct dependency, we need to load it early to prevent a
# circular dependency in hateoas_response.rb
require 'routemaster/resources/rest_resource'

# Loading the Faraday adapter for Typhoeus requires a little dance
require 'faraday/adapter/typhoeus'
require 'typhoeus/adapters/faraday'

# The following requires are not direct dependencies, but loading them early
# prevents Faraday's magic class loading pixie dust from tripping over itself in
# multithreaded use cases.
require 'uri'
require 'faraday/request/retry'
require 'faraday_middleware/request/encode_json'
require 'faraday_middleware/response/parse_json'
require 'faraday_middleware/response/mashify'
require 'hashie/mash'

module Routemaster
  class APIClient
    DEFAULT_USER_AGENT = ENV.fetch('ROUTEMASTER_API_CLIENT_USER_AGENT') { "RoutemasterDrain - Faraday v#{Faraday::VERSION}" }.freeze

    # Memoize the root resources at Class level so that we don't hit the cache
    # all the time to fetch the root resource before doing anything else.
    @@root_resources = {}

    def initialize(options = {})
      @listener               = options.fetch :listener, nil
      @middlewares            = options.fetch :middlewares, []
      @default_response_class = options.fetch :response_class, nil
      @metrics_client         = options.fetch :metrics_client, nil
      @source_peer            = options.fetch :source_peer, nil
      @retry_attempts         = options.fetch :retry_attempts, 2
      @retry_methods          = options.fetch :retry_methods, Faraday::Request::Retry::IDEMPOTENT_METHODS
      @retry_exceptions       = options.fetch :retry_exceptions, Faraday::Request::Retry::Options.new.exceptions

      connection # warm up connection so Faraday does all it's magical file loading in the main thread
    end

    # Performs a GET HTTP request for the `url`, with optional
    # query parameters (`params`) and additional headers (`headers`).
    #
    # @return an object that responds to `status` (integer), `headers` (hash),
    # and `body`. The body is a `Hashie::Mash` if the response was JSON, a
    # string otherwise.
    def get(url, params: {}, headers: {}, options: {})
      enable_caching = options.fetch(:enable_caching, true)
      response_class = options[:response_class]
      APIClientCircuit.new(url).call do
        _wrapped_response _request(
          :get,
          url: url,
          params: params,
          headers: headers.merge(response_cache_opt_headers(enable_caching))),
          response_class: response_class
      end
    end

    # Same as {{get}}, except with
    def fget(url, **options)
      uri = _assert_uri(url)
      Responses::ResponsePromise.new { get(uri, options) }
    end

    def patch(url, body: {}, headers: {})
      patch_post_or_put(:patch, url, body, headers)
    end

    def post(url, body: {}, headers: {})
      patch_post_or_put(:post, url, body, headers)
    end

    def put(url, body: {}, headers: {})
      patch_post_or_put(:put, url, body, headers)
    end

    def delete(url, headers: {})
      _request(:delete, url: url, body: nil, headers: headers)
    end

    def discover(url)
      @@root_resources[url] ||= get(url)
    end

    private

    def patch_post_or_put(type, url, body, headers)
      _wrapped_response _request(
        type,
        url: url,
        body: body,
        headers: headers)
    end

    def _assert_uri(url)
      return url if url.kind_of?(URI)
      URI.parse(url)
    end

    def _request(method, url:, body: nil, headers:, params: {})
      uri = _assert_uri(url)
      auth = auth_header(uri.host)
      headers = [*user_agent_header, *auth, *headers].to_h
      connection.public_send(method) do |req|
        req.url uri.to_s
        req.params.merge! params
        req.headers = headers
        req.body = body
      end
    end

    def _wrapped_response(response, response_class: nil)
      response_class = response_class || @default_response_class
      response_class ? response_class.new(response, client: self) : response
    end

    def connection
      @connection ||= Faraday.new do |f|
        f.request :json
        f.request :retry,
          max: @retry_attempts,
          interval: 100e-3,
          backoff_factor: 2,
          methods: @retry_methods,
          exceptions: @retry_exceptions
        f.response :mashify
        f.response :json, content_type: /\bjson/
        f.use Routemaster::Middleware::ResponseCaching, listener: @listener
        f.use Routemaster::Middleware::Metrics, client: @metrics_client, source_peer: @source_peer
        f.use Routemaster::Middleware::ErrorHandling

        @middlewares.each do |middleware|
          f.use(*middleware)
        end

        f.adapter :typhoeus

        f.options.timeout      = ENV.fetch('ROUTEMASTER_CACHE_TIMEOUT', 1).to_f
        f.options.open_timeout = ENV.fetch('ROUTEMASTER_CACHE_TIMEOUT', 1).to_f
        f.ssl.verify           = ENV.fetch('ROUTEMASTER_CACHE_VERIFY_SSL', 'false') == 'true'
      end
    end

    def auth_header(host)
      auth_string = Config.cache_auth.fetch(host, []).join(':')
      { 'Authorization' => "Basic #{Base64.strict_encode64(auth_string)}" }
    end

    def user_agent_header
      { 'User-Agent' => @source_peer || DEFAULT_USER_AGENT }
    end

    def response_cache_opt_headers(value)
      { Routemaster::Middleware::ResponseCaching::RESPONSE_CACHING_OPT_HEADER => value.to_s }
    end
  end
end
