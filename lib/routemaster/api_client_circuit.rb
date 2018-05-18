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
      ENV.fetch('ROUTEMASTER_ENABLE_API_CLIENT_CIRCUIT', 'NO') =~ /\A(YES|TRUE|ON|1)\Z/i
    end

    def circuit
      Circuitbox.circuit(@circuit_name, {
        sleep_window: configuration_setting(@circuit_name, 'ROUTEMASTER_CIRCUIT_BREAKER_SLEEP_WINDOW', 60).to_i,
        time_window: configuration_setting(@circuit_name, 'ROUTEMASTER_CIRCUIT_BREAKER_TIME_WINDOW', 120).to_i,
        volume_threshold: configuration_setting(@circuit_name, 'ROUTEMASTER_CIRCUIT_BREAKER_VOLUME_THRESHOLD', 50).to_i,
        error_threshold:  configuration_setting(@circuit_name, 'ROUTEMASTER_CIRCUIT_BREAKER_ERROR_THRESHOLD', 50).to_i,
        cache: Moneta.new(:Redis, backend: Config.cache_redis),
        exceptions: [Routemaster::Errors::FatalResource, Faraday::TimeoutError]
      })
    end

    def configuration_setting(circuit_name, setting_name, default)
      ENV.fetch("#{circuit_name}.#{setting_name}", ENV.fetch(setting_name, default))
    end
  end
end
