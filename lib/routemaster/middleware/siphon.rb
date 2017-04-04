module Routemaster
  module Middleware
    class Siphon
      # Filters out events based on their topic and passes them to a handling class
      # Usage:
      #    use Middleware::Siphon, 'some_topic' => SomeTopicSeriesBuilder
      def initialize(app, processors)
        @app = app
        @processors = processors
      end

      def topics_to_avoid
        @processors.keys
      end

      def call(env)
        time_series, payloads = env.fetch('routemaster.payload', []).partition do |event|
          topics_to_avoid.include? event['topic']
        end
        time_series.each do |event|
          @processors[event['topic']].new(event).call
        end
        env['routemaster.payload'] = payloads
        @app.call(env)
      end
    end
  end
end
