require 'routemaster/middleware/root_post_only'
require 'routemaster/middleware/authenticate'
require 'routemaster/middleware/parse'
require 'routemaster/drain/terminator'
require 'rack/builder'
require 'delegate'

module Routemaster
  module Drain
    # Rack application which authenticates, parses, and broadcasts events
    # received from Routemaster.
    #
    # See the various corresponding middleware for details on operation:
    # {Middleware::Authenticate}, {Middleware::Parse}, and terminates with
    # {Rack::Terminator}.
    #
    class Basic
      extend Forwardable

      def initialize(options = {})
        @terminator = terminator = Terminator.new
        @app = ::Rack::Builder.app do
          use Middleware::RootPostOnly
          use Middleware::Authenticate, options
          use Middleware::Parse
          run terminator
        end
      end

      # delegate :call => :@app

      def call(env)
        @app.call(env)
      end

      delegate [:on, :subscribe] => :@terminator
    end
  end
end

