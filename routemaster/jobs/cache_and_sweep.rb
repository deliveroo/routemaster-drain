require 'routemaster/cache'
require 'routemaster/dirty/map'

module Routemaster
  module Jobs
    class CacheAndSweep
      def self.perform(url)
        Dirty::Map.new.sweep_one(url) do
          Cache.new.get(url)
        end
      end
    end
  end
end
