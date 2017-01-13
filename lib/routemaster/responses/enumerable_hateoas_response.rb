require 'forwardable'

module Routemaster
  module Responses
    class EnumerableHateoasResponse
      include Enumerable
      extend Forwardable

      def_delegators :@hateoas_response, :method_missing, :response, :client

      def initialize(hateoas_response, future: false)
        @future = future
        @hateoas_response = hateoas_response
        @resources = lazy_list_of_resources_in_pages
      end

      def each(&block)
        @resources ||= []
        @resources.each(&block)
      end

      private

      attr_reader :future

      def resource_name
        response.env.url.path.split('/').last
      end

      def lazy_list_of_resources_in_pages
        Enumerator.new do |y|
          resources = @hateoas_response.send(resource_name, future: future)
          shovel_resources_into_yielder(resources, y)

          hateoas_response = @hateoas_response
          while(hateoas_response.next_page_link)
            hateoas_response = client.get(hateoas_response.next_page_link)
            resources = hateoas_response.send(resource_name, future: future)
            shovel_resources_into_yielder(resources, y)
          end
        end
      end

      def shovel_resources_into_yielder(resources, yielder)
        resources.each do |r|
          yielder << r
        end
      end
    end
  end
end
