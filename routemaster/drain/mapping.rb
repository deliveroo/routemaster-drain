require 'routemaster/middleware/root_post_only'
require 'routemaster/middleware/authenticate'
require 'routemaster/middleware/parse'
require 'routemaster/middleware/filter'
require 'routemaster/middleware/dirty'
require 'routemaster/drain/terminator'
require 'rack/builder'
require 'delegate'

module Routemaster
  module Drain
    # Rack application which authenticates, parses, filters, pushes to a dirty map,
    # and finally broadcasts events received from Routemaster.
    #
    # The dirty map can be obtained, for further processing, using
    # `Dirty::Map.new`.
    #
    # See the various corresponding middleware for details on operation:
    # {Middleware::RootPostOnly}, {Middleware::Authenticate},
    # {Middleware::Parse}, {Middlewere::Filter}, {Middleware::Dirty},
    # and {Terminator}.
    #
    class Mapping
      extend Forwardable

      def initialize(options = {})
        @terminator = terminator = Terminator.new
        @app = ::Rack::Builder.new do
          use Middleware::RootPostOnly
          use Middleware::Authenticate, options
          use Middleware::Parse
          use Middleware::Filter,       options
          use Middleware::Dirty,        options
          run terminator
        end
      end

      delegate :call => :@app
      delegate [:on, :subscribe] => :@terminator
    end
  end
end

