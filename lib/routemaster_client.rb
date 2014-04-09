require 'routemaster_client/version'
require 'routemaster_client/openssl'
require 'uri'
require 'faraday'
require 'json'

module Routemaster
  class Client
    def initialize(options = {})
      @_url = _assert_valid_url(options[:url])
      @_uuid = options[:uuid]
      _assert (options[:uuid] =~ /^[a-z0-9_-]{1,64}$/), 'uuid should be alpha'
      
      _conn.get('/pulse').tap do |response|
        puts response.status
        puts response.headers.inspect
        raise 'cannot connect to bus' unless response.success?
      end
      nil
    end

    def created(topic, callback)
      _send_event('create', topic, callback)
    end

    def updated(topic, callback)
      _send_event('update', topic, callback)
    end

    def deleted(topic, callback)
      _send_event('delete', topic, callback)
    end

    def noop(topic, callback)
      _send_event('noop', topic, callback)
    end

    def subscribe(options = {})
      if (options.keys - [:topics, :callback, :timeout, :max]).any?
        raise ArgumentError.new('bad options')
      end
      _assert options[:topics].kind_of?(Enumerable), 'topics required'
      _assert options[:callback], 'callback required'
      _assert_valid_timeout options[:timeout] if options[:timeout]
      _assert_valid_max_events options[:max] if options[:max]

      options[:topics].each { |t| _assert_valid_topic(t) }
      _assert_valid_url(options[:callback])

      data = options.to_json
      response = _conn.post('/subscription') do |r|
        r.headers['Content-Type'] = 'application/json'
        r.body = data
      end
      # $stderr.puts response.status
      unless response.success?
        raise "subscription rejected"
      end
    end


    private

    def _assert_valid_timeout(timeout)
      _assert (timeout.kind_of?(Integer) && (0..3_600_000).include?(timeout)),
        'bad timeout'
    end

    def _assert_valid_max_events(max)
      _assert (max.kind_of?(Integer) && (0..10_000).include?(max)),
        'bad max # events'
    end

    def _assert_valid_url(url)
      uri = URI.parse(url)
      _assert (uri.scheme == 'https'), 'HTTPS required'
      return url
    end

    def _assert_valid_topic(topic)
      _assert (topic =~ /^[a-z_]{1,32}$/), 'bad topic name'
    end

    def _send_event(event, topic, callback)
      _assert_valid_url(callback)
      _assert_valid_topic(topic)
      data = { event: event, url: callback }.to_json
      response = _conn.post("/topics/#{topic}") do |r|
        r.headers['Content-Type'] = 'application/json'
        r.body = data
      end
      fail "event rejected (#{response.status})" unless response.success?
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
