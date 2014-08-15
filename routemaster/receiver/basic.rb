require 'routemaster/rack/basic'
require 'delegate'

module Routemaster
  module Receiver
    # Rack middleware which mounts and runs {Routemaster::Rack::Basic}
    # on a given path.
    class Basic
      extend Forwardable

      def initialize(app, options = {})
        @app = ::Rack::Builder.new do
          map options[:path] do
            run Rack::Basic.new(options)
          end
          run app
        end
      end

      delegate :call => :@app
    end
  end
end
