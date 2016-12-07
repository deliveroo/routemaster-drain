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

      def initialize(redis: nil)
        @redis = redis || Config.drain_redis
      end

      # Marks an entity as dirty.
      # Return true if newly marked, false if re-marking.
      def mark(url)
        @redis.sadd(KEY, url).tap do |marked|
          publish(:dirty_entity, url) if marked
        end
      end

      # Runs the block.
      # The entity will only be marked as clean if the block returns truthy.
      def sweep_one(url, &block)
        return unless block.call(url)
        @redis.srem(KEY, url)
      end

      def all
        @redis.smembers(KEY)
      end

      # Yields URLs for dirty entitities.
      # The entity will only be marked as clean if the block returns truthy.
      # It is possible to call +next+ or +break+ from the block.
      def sweep(limit = 0)
        unswept = []
        while url = @redis.spop(KEY)
          unswept.push url
          is_swept = !! yield(url)
          unswept.pop if is_swept
          break if (limit -=1).zero?
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
