require 'wisper'

module Routemaster
  module Middleware
    # If an event payload has been placed in `env['routemaster.payload']`
    # by upper middleware, broadcasts the `:events_received` event with the
    # payload.
    #
    # Nothing will be broadcast if the payload is empty.
    class Broadcast
      include Wisper::Publisher
      
      # @param handler [Proc] *Deprecated*. Gets called with a payload when
      # events have been parsed.
      def initialize(app, options = {})
        if options[:handler]
          Kernel.warn 'the :handler option is deprecated, listen to the :events_received event instead'
          @handler = options[:handler]
        end
        @app = app
      end

      def call(env)
        payload = env['routemaster.payload']
        if payload && payload.any?
          publish(:events_received, payload)
          @handler.on_events(payload) if @handler
        end
        @app.call(env)
      end
    end
  end
end



