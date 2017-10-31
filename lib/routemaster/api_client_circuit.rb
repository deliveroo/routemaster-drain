require 'circuitbox'
require 'routemaster/errors'
module Routemaster
  class APIClientCircuit
    def initialize(url)
      url = URI.parse(url) unless url.is_a? URI
      @circuit_name = url.host.downcase
    end

    def call(&block)
      if enabled?
        begin
          return circuit.run!(&block)
        rescue Circuitbox::ServiceFailureError => e
          raise e.original
        end
      else
        return block.call
      end
    end

    private

    def enabled?
      ENV.fetch('ENABLE_API_CLIENT_CIRCUIT', 'NO') =~ /\A(YES|TRUE|ON|1)\Z/i
    end

    def circuit
      Circuitbox.circuit(@circuit_name, {
        cache: Moneta.new(:Redis, backend: Config.cache_redis),
        sleep_window: 60,
        volume_threshold: 50,
        time_window: 120,
        error_threshold:  50,
        timeout_seconds:  1,
        exceptions: [Routemaster::Errors::FatalResource, Faraday::TimeoutError]
      })
    end
  end
end
