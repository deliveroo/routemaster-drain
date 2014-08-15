require 'json'

module Routemaster
  module Middleware
    # Receives a JSON payload of Routemaster events and parses it.
    #
    # This middleware will ignore requests expect to the root path (+PATH_INFO+
    # must be the empty string), so you may want to use it in conjunction with
    # `Rack::Builder#map` or `Rack::URLMap` directly.
    #
    # It also ignores anything but POST with `application/json` MIMEs.
    #
    # Lower middlewares (or the app) can access the parsed payload as a hash
    # in +env['routemaster.payload']+
    class Parse
      def initialize(app, options = {})
        @app  = app
      end

      def call(env)
        if _should_parse?(env)
          env['routemaster.payload'] ||= _extract_payload(env)
        end
        @app.call(env)
      end

      private

      def _should_parse?(env)
        env['PATH_INFO'] == '' && 
        env['REQUEST_METHOD'] == 'POST' &&
        env['CONTENT_TYPE'] == 'application/json'
      end
      
      def _extract_payload(env)
        JSON.parse(env['rack.input'].read)
      end
    end
  end
end


