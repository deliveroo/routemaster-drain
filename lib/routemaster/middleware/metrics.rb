module Routemaster
  module Middleware
    class Metrics
      INTERACTION_KEY = 'api_client'.freeze

      def initialize(app, client: nil, source_peer: nil)
        @app    = app
        @client = client
        @source_peer = source_peer
      end

      def call(request_env)
        return @app.call(request_env) unless can_log?

        increment_req_count(request_tags(request_env))

        record_latency(request_tags(request_env)) do
          begin
            @app.call(request_env).on_complete do |response_env|
              increment_response_count(response_tags(response_env))
            end
          rescue Routemaster::Errors::BaseError => e
            increment_response_count(response_tags(e.env))
            raise e
          end
        end
      end

      private

      attr_reader :client, :source_peer

      def increment_req_count(tags)
        client.increment("#{INTERACTION_KEY}.request.count", tags: tags)
      end

      def increment_response_count(tags)
        client.increment("#{INTERACTION_KEY}.response.count", tags: tags)
      end

      def record_latency(tags, &block)
        client.time("#{INTERACTION_KEY}.latency", tags: tags) do
          block.call
        end
      end

      def can_log?
        client && source_peer
      end

      def destination_peer(env)
        env.url.host
      end

      def peers_tags(env)
        [
          "source:#{source_peer}",
          "destination:#{destination_peer(env)}"
        ]
      end

      def request_tags(env)
        peers_tags(env).concat(["verb:#{env.method}"])
      end

      def response_tags(env)
        peers_tags(env).concat(["status:#{env.status}"])
      end
    end
  end
end
