module Routemaster
  module Errors
    class BaseError < RuntimeError
      attr_reader :env

      def initialize(env)
        @env = env
        super(message)
      end

      def errors
        body['errors']
      end

      def message
        raise NotImplementedError
      end

      def body
        @body ||= deserialized_body
      end

      private

      def deserialized_body
        @env.body.empty? ? {} : JSON.parse(@env.body)
      end
    end

    class UnauthorizedResourceAccessError < BaseError
      def message
        "Unauthorized Resource Access Error"
      end
    end

    class InvalidResourceError < BaseError
      def message
        "Invalid Resource Error"
      end
    end

    class ResourceNotFoundError < BaseError
      def message
        "Resource Not Found Error"
      end
    end

    class FatalResourceError < BaseError
      def message
        "Fatal Resource Error. body: #{body}, url: #{env.url}, method: #{env.method}"
      end
    end

    class ConflictResourceError < BaseError
      def message
        "ConflictResourceError Resource Error"
      end
    end

    class IncompatibleVersionError < BaseError
      def message
        headers = env.request_headers.select { |k, _| k != 'Authorization' }
        "Incompatible Version Error. headers: #{headers}, url: #{env.url}, method: #{env.method}"
      end
    end

    class ResourceThrottlingError < BaseError
      def message
        "Resource Throttling Error"
      end
    end
  end
end
