require 'routemaster/cache'
require 'routemaster/dirty/map'

module Routemaster
  module Jobs
    # Caches a URL using {Cache} and sweeps the dirty map if successful.
    # Busts the cache if the resource was deleted.
    class CacheAndSweep
      def perform(url, options = {})
        @source_peer = options[:source_peer]
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
        @cache ||= Routemaster::Cache.new(
          client_options: client_options
        )
      end

      def client_options
        if @source_peer
          { source_peer: @source_peer }
        else
          {}
        end
      end

    end
  end
end
