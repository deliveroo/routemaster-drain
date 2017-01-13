require 'faraday_middleware'
require 'routemaster/api_client'
require 'routemaster/resources/rest_resource'
require 'forwardable'

module Routemaster
  module Responses
    class HateoasResponse
      extend Forwardable

      attr_reader :response, :client
      def_delegators :@response, :body, :status, :headers, :success?

      def initialize(response, client: nil)
        @response = response
        @client = client || Routemaster::APIClient.new(response_class: Routemaster::Responses::HateoasResponse)
      end

      def method_missing(m, *args, **kwargs, &block)
        future = kwargs.fetch(:future) { false }

        method_name = m.to_s
        normalized_method_name = method_name == '_self' ? 'self' : method_name

        if _links.keys.include?(normalized_method_name)
          unless respond_to?(method_name)
            define_singleton_method(method_name) do |*m_args, **m_kwargs|
              future = m_kwargs.fetch(:future) { false }
              build_resource(normalized_method_name, future: future)
            end
          end
          self.send(method_name, future: future)
        elsif body.keys.include?(normalized_method_name)
          unless respond_to?(method_name)
            define_singleton_method(method_name) do |*m_args, **m_kwargs|
              body[method_name]
            end
          end
          self.send(method_name)
        else
          super
        end
      end

      def body_without_links
        body.tap { |b| b.delete('_links') }
      end

      def has?(link)
        _links.has_key?(link.to_s)
      end

      def next_page_link
        @_next_page_link ||= _links.fetch('next', nil)
      end

      private

      def build_resource(resource_name, future:)
        resource = _links[resource_name]
        if resource.is_a? Hash
          build_resource_from_href(resource['href'], future: future)
        else
          list_of_resources(resource, future: future)
        end
      end

      def list_of_resources(list, future:)
        list.map do |single_resource|
          build_resource_from_href(single_resource['href'], future: future)
        end
      end

      def build_resource_from_href(href, future:)
        if future
          Resources::RestResource.new(href, client: @client).future_show
        else
          Resources::RestResource.new(href, client: @client)
        end
      end

      def _links
        @links ||= @response.body.fetch('_links', {})
      end
    end
  end
end
