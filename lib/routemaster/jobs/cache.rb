require 'routemaster/cache'

module Routemaster
  module Jobs
    class Cache
      def self.perform(url)
        Cache.new.get(url)
      end
    end
  end
end
