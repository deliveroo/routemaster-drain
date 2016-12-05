require 'routemaster/cache'

module Routemaster
  module Jobs
    # Caches a URL using {Cache}.
    class Cache
      begin
        require 'sidekiq'
        include Sidekiq::Worker
      rescue LoadError
      end

      def self.perform(url)
        Cache.new.get(url)
      end

      def perform(url)
        self.class.perform(url)
      end
    end
  end
end
