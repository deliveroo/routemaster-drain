module Routemaster
  module Middleware
    # Rejects all requests but POST to the root path
    class RootPostOnly
      def initialize(app)
        @app  = app
      end

      def call(env)
        return [404, {}, []] if env['PATH_INFO'] != '/'
        return [405, {}, []] if env['REQUEST_METHOD'] != 'POST'
        @app.call(env)
      end
    end
  end
end


