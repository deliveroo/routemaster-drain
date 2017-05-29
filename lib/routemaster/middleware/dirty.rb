require 'routemaster/dirty/map'

module Routemaster
  module Middleware
    # If an event payload was place in the environment
    # (`env['routemaster.payload']`) by a previous middleware,
    # mark each corresponding entity as dirty.
    #
    # All events are passed through.
    #
    # The dirty map is passed as `:map` to the constructor and must respond to
    # `#mark` (like `Routemaster::Dirty::Map`).
    class Dirty
      def initialize(app, dirty_map: nil, **_)
        @app = app
        @map = dirty_map || Routemaster::Dirty::Map.new
      end

      def call(env)
        env['routemaster.dirty'] = dirty = []

        env.fetch('routemaster.payload', []).each do |event|
          next if event['type'] == 'noop'
          next unless @map.mark(event['url'])
          dirty << event['url']
        end
        @app.call(env)
      end
    end
  end
end
