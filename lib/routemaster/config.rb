require 'singleton'
require 'hashie/rash'
require 'set'
require 'routemaster/redis_broker'
require 'routemaster/null_logger'

module Routemaster
  class Config
    include Singleton
    module Classmethods
      def method_missing(method, *args, &block)
        instance.send(method, *args, &block)
      end

      def respond_to?(method, include_all = false)
        instance.respond_to?(method, include_all)
      end
    end
    extend Classmethods

    attr_writer :logger

    def logger
      @logger ||= NullLogger.new
    end

    def drain_redis
      RedisBroker.instance.get(:drain_redis, urls: ENV.fetch('ROUTEMASTER_DRAIN_REDIS', '').split(','))
    end

    def cache_redis
      RedisBroker.instance.get(:cache_redis, urls: ENV.fetch('ROUTEMASTER_CACHE_REDIS', '').split(','))
    end

    #
    # Given an ENV format of service:service_root_url,other_service:other_service_root_url
    # Generate a hash of { service => service_root_url, other_service => other_service_root_url }
    #
    def hosts
      @hosts ||= begin
                   hosts = ENV['ROUTEMASTER_DRAIN_HOSTS'].split(',')
                   hosts.inject({}) do |res, host|
                     key, val = host.split(':')
                     res.merge(key => val)
                   end
                 end
    end

    def cache_expiry
      Integer(ENV.fetch('ROUTEMASTER_CACHE_EXPIRY', 86_400 * 365))
    end

    def cache_auth
      @cache_auth ||= Hashie::Rash.new.tap do |result|
        ENV.fetch('ROUTEMASTER_CACHE_AUTH', '').split(',').each do |entry|
          host, username, password = entry.split(':')
          result[Regexp.new(host)] = [username, password]
        end
      end
    end

    def queue_adapter
      ENV.fetch('ROUTEMASTER_QUEUE_ADAPTER', 'resque').to_sym
    end

    def queue_name
      ENV.fetch('ROUTEMASTER_QUEUE_NAME', 'routemaster')
    end

    def drain_tokens
      Set.new(ENV.fetch('ROUTEMASTER_DRAIN_TOKENS').split(','))
    end
  end
end
