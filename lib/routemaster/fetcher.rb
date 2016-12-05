require 'faraday'
require 'faraday_middleware'
require 'hashie'
require 'routemaster/config'

module Routemaster
  # Fetches URLs from JSON APIs.
  class Fetcher
    module ClassMethods
      # Calls `get` with the same arguments on a memoized instance
      # for the URL's host.
      def get(url, params:nil, headers:nil)
        _connection_for(url).get(url, params:params, headers:headers)
      end

      private

      def _connection_for(url)
        host = URI.parse(url).host
        @connections ||= {}
        @connections[host] ||= new(host)
      end
    end
    extend ClassMethods

    def initialize(host)
      @host = host
    end

    # Performs a GET HTTP request for the `url`, with optional
    # query parameters (`params`) and additional headers (`headers`).
    #
    # @return an object that responds to `status` (integer), `headers` (hash),
    # and `body`. The body is a `Hashie::Mash` if the response was JSON, a
    # string otherwise.
    def get(url, params:nil, headers:nil)
      r = _connection.get(url, params, headers)
      Hashie::Mash.new(status: r.status, headers: r.headers, body: r.body)
    end

    private

    def _connection
      @_connection ||= Faraday.new do |f|
        f.request  :retry, max: 2, interval: 100e-3, backoff_factor: 2
        f.basic_auth *_uuid if _uuid
        f.response :mashify
        f.response :json, content_type: /\bjson/
        f.adapter  :net_http_persistent

        f.options.timeout      = ENV.fetch('ROUTEMASTER_CACHE_TIMEOUT', 1).to_f
        f.options.open_timeout = ENV.fetch('ROUTEMASTER_CACHE_TIMEOUT', 1).to_f
        f.ssl.verify           = ENV.fetch('ROUTEMASTER_CACHE_VERIFY_SSL', 'false') == 'true'
      end
    end

    def _uuid
      @_uuid ||= Config.cache_auth[@host]
    end
  end
end

