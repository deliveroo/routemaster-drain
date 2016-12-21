module Routemaster
  module Errors
    class BaseError < RuntimeError
      attr_reader :env

      def initialize(env)
        @env = env
        super(message)
      end

      def errors
        body.fetch('errors', {})
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

    class UnauthorizedResourceAccess < BaseError
      def message
        "Unauthorized Resource Access Error"
      end
    end

    class InvalidResource < BaseError
      def message
        "Invalid Resource Error"
      end
    end

    class ResourceNotFound < BaseError
      def message
        "Resource Not Found Error"
      end
    end

    class FatalResource < BaseError
      def message
        "Fatal Resource Error. body: #{body}, url: #{env.url}, method: #{env.method}"
      end
    end

    class ConflictResource < BaseError
      def message
        "ConflictResourceError Resource Error"
      end
    end

    class IncompatibleVersion < BaseError
      def message
        headers = env.request_headers.select { |k, _| k != 'Authorization' }
        "Incompatible Version Error. headers: #{headers}, url: #{env.url}, method: #{env.method}"
      end
    end

    class ResourceThrottling < BaseError
      def message
        "Resource Throttling Error"
      end
    end
  end
end
