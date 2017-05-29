module Routemaster
  module Middleware
    class PayloadFilter
      # Filters duplicate events by url and type in a single payload.
      def run(payload)
        payload.group_by { |event| [event['url'], event['type']] }.map { |_, events| events.last }
      end
    end
  end
end
