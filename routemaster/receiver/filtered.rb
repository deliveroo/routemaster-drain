require 'routemaster/rack/filtered'
require 'rack/builder'
require 'delegate'

module Routemaster
  module Receiver
    # Rack middleware which mounts and runs {Routemaster::Rack::Filtered}
    # on a given path.
    class Filtered
      extend Forwardable

      def initialize(app, options = {})
        @app = ::Rack::Builder.new do
          map options[:path] do
            run Rack::Filtered.new(options)
          end
          run app
        end
      end

      delegate :call => :@app
    end
  end
end
