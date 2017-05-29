module Routemaster
  module Middleware
    # Filters out events based on their topic and passes them to a handling class
    #
    # `use Middleware::Siphon, 'siphon_events' => {'some_topic' => SomeTopicHandler`}
    #
    #  Topic handlers are initialized with the full event payload and must respond to `#call`
    class Siphon
      def initialize(app, siphon_events: nil)
        @app = app
        @processors = siphon_events || {}
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
        @topics_to_siphon ||= @processors.keys.map(&:to_s)
      end
    end
  end
end
