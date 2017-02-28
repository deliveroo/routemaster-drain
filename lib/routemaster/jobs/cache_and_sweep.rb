require 'routemaster/cache'
require 'routemaster/dirty/map'

module Routemaster
  module Jobs
    # Caches a URL using {Cache}, and sweeps the dirty map
    # if sucessful.
    class CacheAndSweep
      def perform(url)
        Dirty::Map.new.sweep_one(url) do
          begin
            Routemaster::Cache.new.get(url)
          rescue Errors::ResourceNotFound
            nil # nothing to cache
          end
        end
      end
    end
  end
end
