require 'delegate'
require 'set'
require 'wisper'

module Routemaster
  module Dirty
    # Collects information about entities whose state has changed and need to be
    # refreshed.
    # Typically +mark+ is called when notified state has changed (e.g. from the
    # bus) and +sweep+ when one wants to know what has changed.
    # 
    # Use case: when some entites are very volatile, the map will hold a "dirty"
    # state for multiple updates until the client is ready to update.
    #
    class Map
      include Wisper::Publisher
      KEY = 'dirtymap:items'

      def initialize(redis)
        @redis = redis
      end

      # Marks an entity as dirty
      def mark(url)
        is_added = @redis.sadd(KEY, url)
        publish(:dirty_entity, url) if is_added
      end

      def sweep_one(url)
        @redis.srem(KEY, url)
      end

      # Yields URLs for dirty entitities.
      # The entity will only be marked as clean if the block returns truthy.
      # It is possible to call +next+ or +break+ from the block.
      def sweep
        unswept = []
        while url = @redis.spop(KEY)
          unswept.push url
          is_swept = !! yield(url)
          unswept.pop if is_swept
        end
      ensure
        @redis.sadd(KEY, unswept) if unswept.any?
      end

      # Number of currently dirty entities.
      def count
        @redis.scard(KEY)
      end
    end
  end
end


__END__

dm.clean(limit: 10) do |state, url|
  
end



