require 'routemaster/middleware/root_post_only'
require 'routemaster/middleware/authenticate'
require 'routemaster/middleware/parse'
require 'routemaster/middleware/siphon'
require 'routemaster/middleware/filter'
require 'routemaster/middleware/dirty'
require 'routemaster/middleware/cache'
require 'routemaster/middleware/expire_cache'
require 'routemaster/drain/terminator'
require 'rack/builder'
require 'delegate'

module Routemaster
  module Drain
    # Rack application which authenticates, parses, filters, pushes to a dirty map,
    # busts cache, schedules preemptive caching, and finally broadcasts events
    # received from Routemaster.
    #
    # See the various corresponding middleware for details on operation:
    # {Middleware::RootPostOnly}, {Middleware::Authenticate},
    # {Middleware::Parse}, {Middleware::Filter}, {Middleware::Dirty},
    # {Middleware::Cache} and {Terminator}.
    #
    class Caching
      extend Forwardable

      def initialize(options = {})
        classes = [
          Middleware::RootPostOnly,
          Middleware::Authenticate,
          Middleware::Parse,
          Middleware::ExpireCache,
          Middleware::Siphon,
          Middleware::Filter,
          Middleware::Dirty,
          Middleware::Cache,
        ]
        @terminator = terminator = Terminator.new
        @app = ::Rack::Builder.new do
          classes.each { |c| use(c, options) }
          run terminator
        end
      end

      delegate call: :@app
      delegate [:on, :subscribe] => :@terminator
    end
  end
end
