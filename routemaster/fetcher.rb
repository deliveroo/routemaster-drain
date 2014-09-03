require 'faraday'
require 'faraday_middleware'
require 'hashie'
require 'routemaster/config'

module Routemaster
  # Fetches URLs from JSON APIs
  class Fetcher
    module ClassMethods
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

    def get(url, params:nil, headers:nil)
      r = _connection.get(url, params, headers)
      Hashie::Mash.new(status: r.status, headers: r.headers, body: r.body)
    end

    private
    
    def _connection
      @_connection ||= Faraday.new do |f|
        f.request  :retry, max: 2, interval: 100e-3, backoff_factor: 2
        f.request  :basic_auth, _uuid, 'x'
        f.response :mashify
        f.response :json, content_type: /\bjson/
        f.adapter  :net_http_persistent

        # TODO: make these configurable
        f.options.timeout      = 1.0
        f.options.open_timeout = 1.0
        f.ssl.verify           = false
      end
    end

    def _uuid
      @_uuid ||= Config.cache_auth[@host]
    end
  end
end

