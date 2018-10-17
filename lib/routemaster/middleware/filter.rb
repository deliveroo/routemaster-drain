require 'routemaster/dirty/filter'

module Routemaster
  module Middleware
    # Filters event payloads passed in the environment (in
    # `env['routemaster.payload']`), is any.
    #
    # Will use `Routemaster::Dirty::Filter` by default.
    class Filter
      # @param filter [Routemaster::Dirty::Filter] an event filter (optional;
      # will be created using the `redis` and `expiry` options if not provided)
      def initialize(app, options = {})
        @app    = app
        @filter = options.fetch(:filter) { Routemaster::Dirty::Filter.new }
      end

      def call(env)
        payload = env['routemaster.payload']
        if payload && payload.any?
          env['routemaster.payload'] = @filter.run(payload)
        end
        @app.call(env)
      end
    end
  end
end
