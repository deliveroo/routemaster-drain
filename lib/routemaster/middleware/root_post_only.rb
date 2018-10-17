module Routemaster
  module Middleware
    # Rejects all requests but POST to the root path
    class RootPostOnly
      def initialize(app, _options = {})
        @app  = app
      end

      def call(env)
        return [404, {}, []] unless ['', '/'].include? env['PATH_INFO']
        return [405, {}, []] if env['REQUEST_METHOD'] != 'POST'
        @app.call(env)
      end
    end
  end
end


