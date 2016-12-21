require 'faraday_middleware'
require 'routemaster/errors'

module Routemaster
  module Middleware
    class ErrorHandling < Faraday::Response::Middleware
      ERRORS_MAPPING = {
        (400..400) => Errors::InvalidResource,
        (401..401) => Errors::UnauthorizedResourceAccess,
        (403..403) => Errors::UnauthorizedResourceAccess,
        (404..404) => Errors::ResourceNotFound,
        (409..409) => Errors::ConflictResource,
        (412..412) => Errors::IncompatibleVersion,
        (413..413) => Errors::InvalidResource,
        (429..429) => Errors::ResourceThrottling,
        (407..500) => Errors::FatalResource
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
