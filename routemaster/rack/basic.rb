require 'routemaster/middleware/authenticate'
require 'routemaster/middleware/parse'
require 'routemaster/middleware/broadcast'
require 'routemaster/rack/terminator'
require 'rack/builder'
require 'delegate'

module Routemaster
  module Rack
    # Rack application which authenticates, parses, and broadcasts events
    # received from Routemaster.
    #
    # See the various corresponding middleware for details on operation:
    # {Middleware::Authenticate}, {Middleware::Parse}, and
    # {Middleware::Broadcast}.
    #
    class Basic
      extend Forwardable

      def initialize(options = {})
        @app = ::Rack::Builder.new do
          use Middleware::Authenticate, options
          use Middleware::Parse,        options
          use Middleware::Broadcast,    options
          run Rack::Terminator.new
        end
      end

      delegate :call => :@app
    end
  end
end

