require 'singleton'
require 'hashie/rash'
require 'set'
require 'routemaster/redis_broker'

module Routemaster
  class Config
    module Classmethods
      def method_missing(method, *args, &block)
        new.send(method, *args, &block)
      end

      def respond_to?(method, include_all = false)
        new.respond_to?(method, include_all)
      end
    end
    extend Classmethods

    def drain_redis
      RedisBroker.instance.get(ENV.fetch('ROUTEMASTER_DRAIN_REDIS'))
    end

    def cache_redis
      RedisBroker.instance.get(ENV.fetch('ROUTEMASTER_CACHE_REDIS'))
    end

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
      Hashie::Rash.new.tap do |result|
        ENV.fetch('ROUTEMASTER_CACHE_AUTH', '').split(',').each do |entry|
          host, username, password = entry.split(':')
          result[Regexp.new(host)] = [username, password]
        end
      end
    end

    def queue_name
      ENV.fetch('ROUTEMASTER_QUEUE_NAME', 'routemaster')
    end

    def drain_tokens
      Set.new(ENV.fetch('ROUTEMASTER_DRAIN_TOKENS').split(','))
    end

    def url_expansions
      Hashie::Rash.new.tap do |result|
        ENV.fetch('ROUTEMASTER_URL_EXPANSIONS', '').split(',').each do |entry|
          host, username, password = entry.split(':')
          result[Regexp.new(host)] = [username, password]
        end
      end
    end
  end
end
