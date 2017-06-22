require 'addressable/template'

require 'routemaster/api_client'
require 'routemaster/responses/hateoas_enumerable_response'
require 'routemaster/responses/hateoas_response'

module Routemaster
  module Resources
    class RestResource
      def initialize(url, client: nil)
        @url_template = Addressable::Template.new(url)
        @client = client || Routemaster::APIClient.new
      end

      def create(params)
        @client.post(expanded_url, body: params)
      end

      def show(id=nil, enable_caching: true)
        @client.get(expanded_url(id: id), options: { enable_caching: enable_caching })
      end

      def index(params: {}, filters: {}, enable_caching: false)
        @client.get(
          expanded_url, params: params.merge(filters), options: {
            enable_caching: enable_caching,
            response_class: Responses::HateoasEnumerableResponse
          }
        )
      end

      def update(id=nil, params)
        @client.patch(expanded_url(id: id), body: params)
      end

      def destroy(id=nil)
        # no response wrapping as DELETE is supposed to 204.
        @client.delete(expanded_url(id: id))
      end

      def url
        @url_template.pattern
      end

      private

      def expanded_url(**params)
        @url_template.expand(params).to_s
      end
    end
  end
end
