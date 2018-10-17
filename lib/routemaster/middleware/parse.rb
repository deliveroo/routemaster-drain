require 'json'
require 'hashie'

module Routemaster
  module Middleware
    # Receives a JSON payload of Routemaster events and parses it.
    #
    # It also ignores anything but POST with `application/json` MIMEs.
    #
    # Lower middlewares (or the app) can access the parsed payload as a hash
    # in +env['routemaster.payload']+
    class Parse
      def initialize(app, _options = {})
        @app  = app
      end

      def call(env)
        if (env['CONTENT_TYPE'] != 'application/json')
          return [415, {}, []]
        end
        if (payload = _extract_payload(env))
          env['routemaster.payload'] = payload
        else
          return [400, {}, []]
        end
        @app.call(env)
      end

      private

      def _extract_payload(env)
        data = JSON.parse(env['rack.input'].read).map { |e| Hashie::Mash.new(e) }
        return nil unless data.kind_of?(Array)
        return nil unless data.all? { |e| e.t && e.type && e.topic && e.url }
        return data
      rescue JSON::ParserError
        nil
      end
    end
  end
end


