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
      include Wisper::Publisher

      def initialize(app, options = {})
        @app = app
        @map = options.fetch(:dirty_map)
      end

      def call(env)
        payload = env['routemaster.payload']
        if payload && payload.any?
          payload.each do |event|
            publish(:sweep_needed) if @map.mark(event['url'])
          end
        end
        @app.call(env)
      end
    end
  end
end



