require 'faraday_middleware'
require 'routemaster/errors'

module Routemaster
  module Middleware
    class ErrorHandling < Faraday::Response::Middleware
      ERRORS_MAPPING = {
        (400..400) => Errors::InvalidResourceError,
        (401..401) => Errors::UnauthorizedResourceAccessError,
        (403..403) => Errors::UnauthorizedResourceAccessError,
        (404..404) => Errors::ResourceNotFoundError,
        (409..409) => Errors::ConflictResourceError,
        (412..412) => Errors::IncompatibleVersionError,
        (413..413) => Errors::InvalidResourceError,
        (429..429) => Errors::ResourceThrottlingError,
        (407..500) => Errors::FatalResourceError
      }.freeze

      def on_complete(env)
        ERRORS_MAPPING.each do |range, error_class|
          if range.include?(env[:status])
            raise error_class.new(env)
          end
        end
      end
    end
  end
end
