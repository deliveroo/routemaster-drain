require 'forwardable'
require 'routemaster/responses/enumerable_hateoas_response'

module Routemaster
  module Responses
    class FutureEnumerableHateoasResponse < EnumerableHateoasResponse
      extend Forwardable

      def initialize(*)
        super
        @hateoas_response.build_resources_with_futures!
      end

      def get_next_page(link)
        client.get(link).tap do |hateoas_response|
          hateoas_response.build_resources_with_futures!
        end
      end
    end
  end
end
