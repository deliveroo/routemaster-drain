require 'routemaster/receiver/basic'
require 'routemaster/dirty/filter'
require 'routemaster/dirty/map'
require 'delegate'
require 'wisper'

module Routemaster
  module Receiver
    class Filtered
      extend Forwardable
      include Wisper::Publisher

      def initialize(app, options = {})
        @redis    = options.fetch(:redis)
        @basic    = Basic.new(app, options)
        @map      = options.fetch(:dirty_map)
        @filter   = Dirty::Filter.new(redis: @redis)

        @basic.subscribe(@filter, prefix: true)
        @filter.on(:entity_changed) { |url| @map.mark(url) }
        @map.on(:dirty_entity) { |url| publish(:sweep_needed) }
      end

      delegate [:call] => :@basic
    end
  end
end
