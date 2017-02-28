require 'forwardable'
require 'routemaster/responses/hateoas_response'

module Routemaster
  module Responses
    # Yields all resources listed in a collection endpoint in a non-greedy,
    # non-recursive manner.
    #
    # Each yielded resource is a future; synchronous requests are performed for
    # each page.
    #
    # NB: the first named collection in the _links section of the payload will
    # be enumerated. Any other named collections will simply be ignored.
    class HateoasEnumerableResponse < HateoasResponse
      include Enumerable

      def each(&block)
        each_page do |items|
          items.each(&block)
        end
      end

      def each_page
        current_page = self
        loop do
          yield _page_items(current_page)
          break unless current_page.has?(:next)
          current_page = current_page.next.index
        end
      end

      private

      def _resource_name
        _links.find { |k,v|
          !%w[curies self].include?(k) && v.kind_of?(Array)
        }.first
      end

      def _page_items(page)
        page.body._links.fetch(_resource_name).map do |link|
          @client.fget(link.href)
        end
      end
    end
  end
end
