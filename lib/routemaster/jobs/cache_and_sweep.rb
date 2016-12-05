require 'routemaster/cache'
require 'routemaster/dirty/map'

module Routemaster
  module Jobs
    # Caches a URL using {Cache}, and sweeps the dirty map
    # if sucessful.
    class CacheAndSweep
      begin
        require 'sidekiq'
        include Sidekiq::Worker
      rescue LoadError
      end

      def self.perform(url)
        Dirty::Map.new.sweep_one(url) do
          Cache.new.get(url)
        end
      end

      def perform(url)
        self.class.perform(url)
      end
    end
  end
end
