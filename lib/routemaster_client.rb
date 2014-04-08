require 'routemaster_client/version'
require 'uri'
require 'faraday'

module Routemaster
  class Client
    def initialize(options = {})
      @_url = URI.parse(options[:url])
      _assert (@_url.scheme == 'https'), 'HTTPS required'

      @_uuid = options[:uuid]
      _assert (options[:uuid] =~ /^[a-z_]{1,32}$/), 'uuid should be alpha'
      
      _conn.get('/pulse')
      nil
    end

    def created(topic, callback)
      _send_event('created', topic, callback)
    end

    def updated(topic, callback)
      _send_event('updated', topic, callback)
    end

    def deleted(topic, callback)
      _send_event('deleted', topic, callback)
    end

    def noop(topic, callback)
      _send_event('noop', topic, callback)
    end


    private

    def _send_event(event, topic, callback)
    end

    def _assert(condition, message)
      condition or raise ArgumentError.new(message)
    end

    def _conn
      @_conn ||= Faraday.new(@_url) do |f|
        f.use      Faraday::Request::BasicAuthentication, @_uuid, 'x'
        f.adapter  Faraday.default_adapter
      end
    end
  end
end
