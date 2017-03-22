require 'core_ext/forwardable'
require 'forwardable'
require 'routemaster/api_client'

module Routemaster
  module Responses
    class HateoasResponse
      extend Forwardable

      attr_reader :response
      def_delegators :@response, :body, :status, :headers, :success?

      def initialize(response, client: nil)
        @response = response
        @client = client || Routemaster::APIClient.new(response_class: self.class)
      end

      def method_missing(m, *args, &block)
        method_name = m.to_s
        normalized_method_name = method_name == '_self' ? 'self' : method_name

        if _links.keys.include?(normalized_method_name)
          unless respond_to?(method_name)
            resource = Resources::RestResource.new(_links[normalized_method_name]['href'], client: @client)
            define_singleton_method(method_name) { resource }
            public_send method_name
          end
        else
          super
        end
      end

      def body_without_links
        body.reject { |key, _| ['_links'].include?(key) }
      end

      def has?(link)
        _links.has_key?(link.to_s)
      end

      private

      def _links
        @links ||= @response.body.fetch('_links', {})
      end
    end
  end
end
