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

      class << self
        def build(response, client: nil)
          if contains_a_list_with_the_same_key_as_the_path?(response) && paginated_and_first_page?(response)
            EnumerableHateoasResponse.new(response, resource_name(response), client: client)
          else
            HateoasResponse.new(response, client: client)
          end
        end

        private

        def contains_a_list_with_the_same_key_as_the_path?(response)
          response.body['_links'].keys.include? resource_name(response)
        end

        def paginated_and_first_page?(response)
          response.body.has_key?('page') && response.body['page'] == 1
        end

        def resource_name(response)
          response.env.url.path.split('/').last
        end
      end

      def initialize(response, client: nil)
        @response = response
        @client = client || Routemaster::APIClient.new(response_class: Routemaster::Responses::HateoasResponse)
      end

      def method_missing(m, *args, &block)
        method_name = m.to_s
        normalized_method_name = method_name == '_self' ? 'self' : method_name

        if _links.keys.include?(normalized_method_name)
          unless respond_to?(method_name)
            define_singleton_method(method_name) do |*m_args|
              build_resource(normalized_method_name)
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

      private

      def build_resource(resource_name)
        resource = _links[resource_name]
        if resource.is_a? Hash
          build_resource_from_href(resource['href'])
        else
          # Must be an Array
          list_of_resources(resource)
        end
      end

      def list_of_resources(list)
        list.map do |single_resource|
          build_resource_from_href(single_resource['href'])
        end
      end

      def build_resource_from_href(href)
        Resources::RestResource.new(href, client: @client)
      end

      def _links
        @links ||= @response.body.fetch('_links', {})
      end

      def lazy_list_of_resources_in_pages(method_name, resource)
        Enumerator.new do |y|
          per_page = @response.body['per_page']
          total = @response.body['total']
          number_of_pages = (total / per_page.to_f).ceil

          resources = list_of_resources(resource)
          (number_of_pages - 1).times do
            shovel_resources_into_yielder(resources, y)
            resource = @client.get(_links['next'])
            resources = resource.send(method_name)
          end
          shovel_resources_into_yielder(resources, y)
        end
      end

      def shovel_resources_into_yielder(resources, yielder)
        resources.each do |r|
          yielder << r
        end
      end

      class EnumerableHateoasResponse < HateoasResponse
        include Enumerable

        def initialize(response, resource_name, client: nil)
          super(response, client: client)
          @resources = lazy_list_of_resources_in_pages(resource_name, _links[resource_name])
        end

        def each(&block)
          @resources ||= []
          @resources.each(&block)
        end
      end
    end
  end
end
