require 'thread/pool'
require 'thread/future'
require 'singleton'
require 'delegate'
require 'forwardable'

module Routemaster
  module Responses
    # Wraps a future response, so it quacks exactly like an ordinary response.
    class FutureResponse
      extend Forwardable

      # The `block` is expected to return a {Response}
      def initialize(&block)
        @future = Pool.instance.future(&block)
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

      delegate :value => :@future
      delegate %i(status headers body) => :value
    end

    # A pool of threads, used for parallel/future request processing.
    class Pool < SimpleDelegator
      include Singleton

      def initialize
        Thread.pool(5, 20).tap do |p|
          # TODO: configurable pool size and trim timeout?
          p.auto_trim!
          p.idle_trim! 10 # 10 seconds
          super p
        end
      end
    end
  end
end
