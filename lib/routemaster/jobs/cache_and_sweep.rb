require 'routemaster/cache'
require 'routemaster/dirty/map'

module Routemaster
  module Jobs
    # Caches a URL using {Cache} and sweeps the dirty map if successful.
    # Busts the cache if the resource was deleted.
    class CacheAndSweep
      def perform(url)
        Dirty::Map.new.sweep_one(url) do
          begin
            cache.get(url)
          rescue Errors::ResourceNotFound
            cache.bust(url)
            true
          end
        end
      end

      private

      def cache
        @cache ||= Routemaster::Cache.new
      end
    end
  end
end
