require 'concurrent/future'
require 'singleton'
require 'delegate'

module Routemaster
  module Responses
    class FutureResponse
      extend Forwardable

      # The `block` is expected to return a {Response}
      def initialize(&block)
        @future = Concurrent::Future.execute(&block)
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
