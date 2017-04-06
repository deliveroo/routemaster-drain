module Routemaster
  module Middleware
    class Siphon
      # Filters out events based on their topic and passes them to a handling class
      # Usage:
      #    use Middleware::Siphon, 'some_topic' => SomeTopicHandler
      def initialize(app, processors)
        @app = app
        @processors = processors
      end

      def call(env)
        siphoned, non_siphoned = env.fetch('routemaster.payload', []).partition do |event|
          topics_to_siphon.include? event['topic']
        end
        siphoned.each do |event|
          @processors[event['topic']].new(event).call
        end
        env['routemaster.payload'] = non_siphoned
        @app.call(env)
      end

      private

      def topics_to_siphon
        @topics_to_siphon ||= @processors.keys
      end
    end
  end
end
