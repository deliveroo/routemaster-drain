require 'routemaster/cache'
require 'routemaster/config'
require 'routemaster/jobs/client'
require 'routemaster/jobs/cache_and_sweep'
require 'routemaster/event_index'

module Routemaster
  module Middleware
    class Cache
      def initialize(app, options = {})
        @app    = app
        @cache  = options.fetch(:cache) { Routemaster::Cache.new }
        @client = options.fetch(:client) { Routemaster::Jobs::Client.new }
        @queue  = options.fetch(:queue) { Config.queue_name }
      end

      def call(env)
        env.fetch('routemaster.dirty', []).each do |url|
          @client.enqueue(@queue, Routemaster::Jobs::CacheAndSweep, url)
        end
        @app.call(env)
      end
    end
  end
end
