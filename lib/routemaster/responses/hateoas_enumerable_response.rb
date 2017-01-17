#
# HateoasEnumerableResponse
# On initialize we scan and append on @collection futures
# based on the items returned from the querie
# i.e:
#   Given:
#   {
#     "_links" : {
#       "next" : { "href" : "https://service/resources?page=2&per_page=2" },
#       "resources" : [
#         { "href" : "resource_url" },
#         { "href" : "resource_url" }
#       ]
#     },
#     "page" : 1,
#     "per_page" : 2,
#     "total" : 5
#   }
#
#   On initialization will do an indirect recursion across all the pages
#
#   page(1) -> [futures of page 3, 2, and 1]
#     |_ page(2) -> [futures of page 3 and 2]
#         |_ page(3) -> [futures of page 3]
#
#   After the above execution page2 and page3 HateoasResponses will be garbage collected

module Routemaster
  module Responses
    class HateoasEnumerableResponse < HateoasResponse
      include Enumerable

      attr_reader :collection

      def initialize(response, client: nil)
        super(response, client: client)
      end

      def each(&block)
        resources_from_body.each do |entry|
          block.call(entry)
        end
      end

      private

      def resources_from_body
        resources = init_futures_from_urls_in_body.map(&:value)
        resources += self.next.index.to_a if has?(:next)
        resources
      end

      def init_futures_from_urls_in_body
        _links.each do |key, urls|
          next if key == 'curies'
          next if key == 'self'

          if urls.is_a?(Array)
            return urls.map { |url| @client.fget(url['href']) }
          end
        end
      end
    end
  end
end
