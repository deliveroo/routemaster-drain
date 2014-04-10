require 'sinatra'
require 'rack/auth/basic'
require 'base64'
require 'json'

module Routemaster
  class Receiver
    def initialize(app, options = {})
      @app     = app
      @path    = options[:path]
      @uuid    = options[:uuid]
      @handler = options[:handler]
    end

    def call(env)
      catch :forward do
        throw :forward unless _intercept_endpoint?(env)
        return [401, {}, ''] unless _has_auth?(env)
        return [403, {}, ''] unless _valid_auth?(env)
        return [400, {}, ''] unless payload = _extract_payload(env)

        @handler.on_events(payload)
        return [204, {}, '']
      end
      @app.call(env)
    end

    private

    def _intercept_endpoint?(env)
      env['PATH_INFO'] == @path && env['REQUEST_METHOD'] == 'POST'
    end

    def _has_auth?(env)
      env.has_key?('HTTP_AUTHORIZATION')
    end

    def _valid_auth?(env)
      Base64.
        decode64(env['HTTP_AUTHORIZATION']).
        split(':').first == @uuid
    end

    def _extract_payload(env)
      return unless env['CONTENT_TYPE'] == 'application/json'
      JSON.parse(rack.input.read)
    end
  end
end
