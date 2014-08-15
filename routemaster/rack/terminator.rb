module Routemaster
  module Rack
    # Tiny app to terminates a middleware chain.
    # 
    # Respond 204 if a payload has been parsed (i.e. present in the environment)
    # and 400 if not.
    class Terminator
      def call(env)
        if env['routemaster.payload']
          [204, {}, []]
        else
          [400, {'Content-Type' => 'text/plain'}, 'no payload parsed']
        end
      end
    end
  end
end
