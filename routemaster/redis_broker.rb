require 'redis-namespace'
require 'uri'
require 'singleton'

module Routemaster
  class RedisBroker
    include Singleton

    def initialize
      @_connections = {}
      _cleanup
    end

    def get(url)
      _check_for_fork
      @_connections[url] ||= begin
        parsed_url = URI.parse(url)
        namespace = parsed_url.path.split('/')[2] || 'rm'
        Redis::Namespace.new(namespace, redis: Redis.new(url: url))
      end
    end

    def cleanup
      _cleanup
    end

    private

    def _check_for_fork
      return if Process.pid != @_pid
      _cleanup
    end

    def _cleanup
      @_pid = Process.pid
      @_connections.each_value(&:quit)
      @_connections = {}
    end

  end
end

