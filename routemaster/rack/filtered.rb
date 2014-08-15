require 'routemaster/middleware/authenticate'
require 'routemaster/middleware/parse'
require 'routemaster/middleware/filter'
require 'routemaster/middleware/dirty'
require 'routemaster/middleware/broadcast'
require 'routemaster/rack/terminator'
require 'rack/builder'
require 'delegate'

module Routemaster
  module Rack
    # Rack application which authenticates, parses, filters, pushes to a dirty map,
    # and finally broadcasts events received from Routemaster.
    #
    # See the various corresponding middleware for details on operation:
    # {Middleware::Authenticate}, {Middleware::Parse}, {Middlewere::Filter},
    # {Middleware::Dirty}, and {Middleware::Broadcast}.
    #
    class Filtered
      extend Forwardable

      def initialize(options = {})
        @app = ::Rack::Builder.new do
          use Middleware::Authenticate, options
          use Middleware::Parse,        options
          use Middleware::Filter,       options
          use Middleware::Dirty,        options
          use Middleware::Broadcast,    options
          run Rack::Terminator.new
        end
      end

      delegate :call => :@app
    end
  end
end

