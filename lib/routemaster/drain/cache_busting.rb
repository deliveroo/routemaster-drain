require 'routemaster/middleware/root_post_only'
require 'routemaster/middleware/authenticate'
require 'routemaster/middleware/parse'
require 'routemaster/middleware/siphon'
require 'routemaster/middleware/expire_cache'
require 'routemaster/middleware/payload_filter'
require 'routemaster/middleware/filter'
require 'routemaster/drain/terminator'
require 'rack/builder'
require 'delegate'

module Routemaster
  module Drain
    # Rack application which authenticates, parses, filters duplicates in this request
    # and invalidates the cache for all updated or new items.
    #
    # See the various corresponding middleware for details on operation:
    # {Middleware::RootPostOnly}, {Middleware::Authenticate},
    # {Middleware::Parse}, {Middleware::ExpireCache} and {Terminator}.
    class CacheBusting
      extend Forwardable

      def initialize(options = {})
        classes = [
          Middleware::RootPostOnly,
          Middleware::Authenticate,
          Middleware::Parse,
          Middleware::Siphon,
          Middleware::Filter,
          Middleware::ExpireCache,
        ]
        @terminator = terminator = Terminator.new
        @app = ::Rack::Builder.new do
          options = options.merge(filter: Routemaster::Middleware::PayloadFilter.new)
          classes.each { |c| use(c, options) }
          run terminator
        end
      end

      delegate call: :@app
      delegate [:on, :subscribe] => :@terminator
    end
  end
end
