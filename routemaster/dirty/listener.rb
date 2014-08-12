require 'delegate'
require 'set'
require 'routemaster/dirty/map'
require 'routemaster/dirty/state'
require 'wisper'

module Routemaster
  module Dirty
    class Listener
      include Wisper::Publisher
      extend Forwardable

      EXPIRY = 86_400

      delegate :sweep => :@map

      def initialize(options = {})
        @redis  = options.fetch(:redis)
        @expiry = options.fetch(:expiry, EXPIRY)
        @topics = options.fetch(:topics, [])
      end

      def on_events_received(payload)
        payload.each do |event|
          # skip event about irrelevant topics
          next unless @topics.empty? || @topics.include?(event['topic'])
          
          known_state = State.get(@redis, event['url'])

          # skip events older than what we already know
          next if known_state.t > event['t']

          new_state = case event['type']
          when 'create', 'update', 'delete'
            State.new(event['url'], event['t'])
          when 'noop'
            # do nothing, state unchanged
            known_state
          else 
            warn 'unknown event type received'
            known_state
          end

          if new_state != known_state
            new_state.save(@redis, @expiry)
            publish(:entity_changed, new_state.url)
          end
        end
      end
    end
  end
end
