require 'concurrent/promise'
require 'concurrent/executor/cached_thread_pool'
require 'singleton'
require 'delegate'

module Routemaster
  module Responses
    class ResponsePromise
      extend Forwardable

      # The `block` is expected to return a {Response}
      def initialize(&block)
        @promise = Concurrent::Promise.new(executor: Pool.current, &block)
      end

      # @!attribute status
      # @return [Integer]
      # Delegated to the `block`'s return value.

      # @!attribute headers
      # @return [Hash]
      # Delegated to the `block`'s return value.

      # @!attribute body
      # @return [Hashie::Mash]
      # Delegated to the `block`'s return value.
      delegate %i(status headers body) => :value
      delegate %i(on_success on_error raise execute state) => :@promise

      delegate :respond_to_missing? => :value

      def method_missing(m, *args, &block)
        value.public_send(m, *args, &block)
      end

      def value
        @promise.value.tap do
          raise @promise.reason if @promise.rejected?
        end
      end

      module Pool
        LOCK = Mutex.new

        def self.current
          LOCK.synchronize do
            @pool ||= _build_pool
          end
        end

        def self.reset
          LOCK.synchronize do
            return unless @pool
            @pool.tap(&:shutdown).wait_for_termination
            @pool = nil
          end
          self
        end

        def self._build_pool
          Concurrent::CachedThreadPool.new(min_length: 5, max_length: 20, max_queue: 0, fallback_policy: :caller_runs)
        end
      end
    end
  end
end
