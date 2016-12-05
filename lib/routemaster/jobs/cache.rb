require 'routemaster/cache'

module Routemaster
  module Jobs
    # Caches a URL using {Cache}.
    class Cache
      def self.perform(url)
        Cache.new.get(url)
      end
    end
  end
end
