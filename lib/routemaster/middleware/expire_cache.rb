require 'routemaster/cache'

module Routemaster
  module Middleware
    class ExpireCache
      def initialize(app, cache:nil)
        @app    = app
        @cache  = cache || Routemaster::Cache.new
      end

      def call(env)
        env.fetch('routemaster.payload', []).each do |event|
          next if event['type'] == 'noop'
          @cache.invalidate(event['url'])
        end
        @app.call(env)
      end
    end
  end
end
