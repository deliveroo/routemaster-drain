require 'redis-namespace'
require 'redis/distributed'
require 'uri'
require 'singleton'

module Routemaster
  class RedisBroker
    include Singleton

    DEFAULT_NAMESPACE = 'rm'.freeze

    def initialize
      @_connections = {}
      _cleanup
    end

    def get(name, urls: [])
      _check_for_fork
      @_connections[name] ||= begin
                                parsed_url = URI.parse(urls.first)
                                namespace = parsed_url.path.split('/')[2] || DEFAULT_NAMESPACE
                                Redis::Namespace.new(namespace, redis: Redis::Distributed.new(urls))
                              end
    end

    def cleanup
      _cleanup
    end

    # Allow to inject pre-built Redis clients
    #
    # Before storing a new connection, ensure that any previously
    # set client is properly closed.
    #
    def inject(clients={})
      @_injected_clients = true
      clients.each_pair do |name, client|
        _close_if_present(@_connections[name])
        @_connections[name] = Redis::Namespace.new(DEFAULT_NAMESPACE, redis: client)
      end
    end

    private

    # Do not clean up if the clients are injected by the host application.
    # In that case connections should be managed the server or worker processes.
    #
    def _check_for_fork
      return if @_injected_clients
      return if Process.pid == @_pid
      _cleanup
    end

    def _cleanup
      @_pid = Process.pid
      @_connections.each_value { |conn| _close_if_present(conn) }
      @_connections = {}
    end

    def _close_if_present(connection)
      if connection.respond_to?(:redis)
        connection.redis.quit
      end
    end

  end
end

