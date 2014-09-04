require 'wisper'

module Routemaster
  module Drain
    # Tiny Rack app to terminates a Routemaster middleware chain.
    # 
    # Respond 204 if a payload has been parsed (i.e. present in the environment)
    # and 400 if not.
    #
    # If an event payload has been placed in `env['routemaster.payload']`
    # by upper middleware, broadcasts the `:events_received` event with the
    # payload.
    #
    # Nothing will be broadcast if the payload is empty.
    #
    class Terminator
      include Wisper::Publisher

      def call(env)
        payload = env['routemaster.payload']
        if payload.nil?
          return [400, {'Content-Type' => 'text/plain'}, 'no payload parsed']
        end

        publish(:events_received, payload) if payload.any?
        [204, {}, []]
      end
    end
  end
end

