require 'faraday_middleware'
require 'routemaster/errors'

module Routemaster
  module Middleware
    class ErrorHandling < Faraday::Response::Middleware
      ERRORS_MAPPING = {
        400 => Errors::InvalidResource,
        401 => Errors::UnauthorizedResourceAccess,
        403 => Errors::UnauthorizedResourceAccess,
        404 => Errors::ResourceNotFound,
        409 => Errors::ConflictResource,
        412 => Errors::IncompatibleVersion,
        413 => Errors::InvalidResource,
        422 => Errors::UnprocessableEntity,
        429 => Errors::ResourceThrottling,
        500 => Errors::FatalResource
      }.freeze

      def on_complete(env)
        error_class = ERRORS_MAPPING[env[:status]]

        raise error_class.new(env) if error_class
      end
    end
  end
end
