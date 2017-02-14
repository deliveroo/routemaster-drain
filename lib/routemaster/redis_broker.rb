require 'redis-namespace'
require 'redis/distributed'
require 'uri'
require 'singleton'

module Routemaster
  class RedisBroker
    include Singleton

    def initialize
      @_connections = {}
      _cleanup
    end

    def get(name, urls: [])
      _check_for_fork
      @_connections[name] ||= begin
                                parsed_url = URI.parse(urls.first)
                                namespace = parsed_url.path.split('/')[2] || 'rm'
                                Redis::Namespace.new(namespace, redis: Redis::Distributed.new(urls))
                              end
    end

    def cleanup
      _cleanup
    end

    private

    def _check_for_fork
      _cleanup unless Process.pid == @_pid
    end

    def _cleanup
      @_pid = Process.pid
      @_connections.each_value(&:quit)
      @_connections = {}
    end

  end
end

