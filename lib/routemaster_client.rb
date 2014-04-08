require 'routemaster_client/version'
require 'uri'
require 'faraday'

module Routemaster
  class Client
    def initialize(options = {})
      @_url = _assert_valid_url(options[:url])
      @_uuid = options[:uuid]
      _assert (options[:uuid] =~ /^[a-z0-9_-]{1,64}$/), 'uuid should be alpha'
      
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

    def _assert_valid_url(url)
      uri = URI.parse(url)
      _assert (uri.scheme == 'https'), 'HTTPS required'
      return url
    end

    def _send_event(event, topic, callback)
      _assert_valid_url(callback)
      _assert (topic =~ /^[a-z_]{1,32}$/), 'bad topic name'
      data = { event: event, url: callback }.to_json
      _conn.post("/topics/#{topic}") do |r|
        r.headers['Content-Type'] = 'application/json'
        r.body = data
      end
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
