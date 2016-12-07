require 'faraday_middleware'
require 'routemaster/resources/rest_resource'
require 'forwardable'
require 'json'

module Routemaster
  module Responses
    class HateoasResponse
      extend Forwardable

      def initialize(response)
        @response = response
      end

      def method_missing(m, *args, &block)
        method_name = m.to_s
        normalized_method_name = method_name == '_self' ? 'self' : method_name

        if _links.keys.include?(normalized_method_name)
          unless respond_to?(method_name)
            resource = Resources::RestResource.new(_links[normalized_method_name]['href'])

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
