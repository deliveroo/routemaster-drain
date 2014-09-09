require 'delegate'
require 'set'

module Routemaster
  module Dirty
    # Locale prepresentation of the state of an entity.
    # - url (string): the entity's authoritative locator
    # - t (datetime, UTC): when the state was last refreshed
    class State < Struct.new(:url, :t)
      KEY = 'dirtymap:state:%s'

      # Given a `redis` instance, return
      #
      # - a "blank" state for that URL (with time stamp 0), if the state is
      #   unknown; or
      # - the entity state, if known.
      def self.get(redis, url)
        data = redis.get(KEY % url)
        return new(url, 0) if data.nil?
        Marshal.load(data)
      end

      # Given a `redis` instance, save the state, expiring after
      # `expiry` seconds.
      def save(redis, expiry)
        data = Marshal.dump(self)
        redis.set(KEY % url, data, ex: expiry)
      end
    end
  end
end


