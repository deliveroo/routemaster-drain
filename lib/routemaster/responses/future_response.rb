require 'thread/pool'
require 'thread/future'
require 'singleton'
require 'delegate'

module Routemaster
  module Responses
    # A pool of threads, used for parallel/future request processing.
    class Pool < SimpleDelegator
      include Singleton

      def initialize
        Thread.pool(5, 20).tap do |p|
          p.auto_trim!
          p.idle_trim! 10 # 10 seconds
          super p
        end
      end
    end

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
      delegate :respond_to_missing? => :value
      
      def method_missing(m, *args, &block)
        value.public_send(m, *args, &block)
      end
    end
  end
end
