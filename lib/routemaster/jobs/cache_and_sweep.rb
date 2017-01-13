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
            Cache.new.get(url)
          rescue Errors::ResourceNotFound
          end
        end
      end
    end
  end
end
