module Routemaster
  module Middleware
    # Filters out events based on their topic and passes them to a handling class
    #
    # `use Middleware::Siphon, 'siphon_events' => {'some_topic' => SomeTopicHandler}`
    #
    # A topic handler can be:
    #   - A class initialized with the full event payload and respondding to `#call`
    #   - An instance that responds to '#call' with the full event payload as argument
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
          processor = @processors[event['topic']]
          if processor.respond_to?(:call)
            processor.call(event)
          else
            warn '[deprecation] handlers that receive event in initializer are deprecated. '\
              'define a `.call` method that receives event.'
            processor.new(event).call
          end
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
