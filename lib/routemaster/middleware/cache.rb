require 'routemaster/cache'
require 'routemaster/config'
require 'routemaster/jobs/client'
require 'routemaster/jobs/cache_and_sweep'
require 'routemaster/event_index'

module Routemaster
  module Middleware
    class Cache
      def initialize(app, cache:nil, client:nil, queue:nil, **_)
        @app    = app
        @cache  = cache || Routemaster::Cache.new
        @client = client || Routemaster::Jobs::Client.new
        @queue  = queue || Config.queue_name
      end

      def call(env)
        env.fetch('routemaster.dirty', []).each do |url|
          @cache.invalidate(url)
          @client.enqueue(@queue, Routemaster::Jobs::CacheAndSweep, url)
        end
        @app.call(env)
      end
    end
  end
end
