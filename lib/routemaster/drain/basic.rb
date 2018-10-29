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
    # {Terminator}.
    #
    class Basic
      extend Forwardable

      def initialize(options = {})
        classes = [
          Middleware::RootPostOnly,
          Middleware::Authenticate,
          Middleware::Parse,
        ]
        @terminator = terminator = Terminator.new
        @app = ::Rack::Builder.app do
          classes.each { |c| use(c, options) }
          run terminator
        end
      end

      def call(env)
        @app.call(env)
      end

      delegate [:on, :subscribe] => :@terminator
    end
  end
end
