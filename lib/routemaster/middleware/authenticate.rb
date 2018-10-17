require 'wisper'
require 'base64'
require 'routemaster/config'

module Routemaster
  module Middleware
    # Authenticates requests according to the Routemaster spec.
    #
    # Broadcasts `:authenticate` with one of `:missing`, `failed`, or
    # `:succeeded`.
    #
    # This is very close to `Rack::Auth::Basic`, in that HTTP Basic
    # is used; but the password part is ignored. In other words, this performs
    # token authentication using HTTP Basic.
    #
    class Authenticate
      include Wisper::Publisher

      # @param uuid [Enumerable] a set of accepted authentication tokens
      def initialize(app, options = {})
        @app  = app
        @uuid = options.fetch(:uuid) { Config.drain_tokens }

        unless @uuid.kind_of?(String) || @uuid.kind_of?(Enumerable)
          raise ArgumentError, ':uuid must be a String or Enumerable'
        end
      end

      def call(env)
        unless _has_auth?(env)
          publish(:authenticate, :missing, env)
          return [401, {}, []]
        end

        unless _valid_auth?(env)
          publish(:authenticate, :failed, env)
          return [403, {}, []]
        end

        publish(:authenticate, :succeeded, env)
        @app.call(env)
      end

      private

      def _has_auth?(env)
        env.has_key?('HTTP_AUTHORIZATION')
      end

      def _valid_auth?(env)
        token = Base64.
          decode64(env['HTTP_AUTHORIZATION'].gsub(/^Basic /, '')).
          split(':').first
        @uuid.include?(token)
      end
    end
  end
end
