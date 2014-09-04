require 'routemaster/cache'
require 'routemaster/config'
require 'routemaster/jobs/cache_and_sweep'
require 'resque'

module Routemaster
  module Middleware
    class Cache
      def initialize(app, cache:nil, resque:nil, queue:nil)
        @app    = app
        @cache  = cache || Routemaster::Cache.new
        @resque = resque || Resque
        @queue  = queue || Config.queue_name
      end

      def call(env)
        env.fetch('routemaster.dirty', []).each do |url|
          @cache.bust(url)
          @resque.enqueue_to(@queue, Routemaster::Jobs::CacheAndSweep, url)
        end
        @app.call(env)
      end
    end
  end
end




