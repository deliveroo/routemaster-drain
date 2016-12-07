require 'faraday_middleware'
require 'routemaster/api_client'
require 'routemaster/responses/hateoas_response'
require 'routemaster/resources/rest_resource'
require 'forwardable'
require 'json'

module Routemaster
  module Responses
    class HateoasResponse
      extend Forwardable

      attr_reader :response
      def_delegators :@response, :body, :status, :headers, :success?

      def initialize(response, client: nil)
        @response = response
        @client = client || Routemaster::APIClient.new(response_class: Routemaster::Responses::HateoasResponse)
      end

      def method_missing(m, *args, &block)
        method_name = m.to_s
        normalized_method_name = method_name == '_self' ? 'self' : method_name

        if _links.keys.include?(normalized_method_name)
          unless respond_to?(method_name)
            resource = Resources::RestResource.new(_links[normalized_method_name]['href'], client: @client)

            self.class.send(:define_method, method_name) do |*m_args|
              resource
            end

            resource
          end
        else
          super
        end
      end

      private

      def _links
        @links ||= JSON.parse(@response.body).fetch('_links', {})
      end
    end
  end
end
