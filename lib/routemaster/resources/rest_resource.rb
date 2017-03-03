require 'routemaster/api_client'
require 'routemaster/responses/hateoas_enumerable_response'
require 'routemaster/responses/hateoas_response'

module Routemaster
  module Resources
    class RestResource
      attr_reader :url

      def initialize(url, client: nil)
        @url = url
        @client = client || Routemaster::APIClient.new
      end

      def create(params)
        @client.with_response(Responses::HateoasResponse) do
          @client.post(@url, body: params)
        end
      end

      def show(id=nil, enable_caching: true)
        @client.with_response(Responses::HateoasResponse) do
          @client.get(@url.gsub('{id}', id.to_s), options: { enable_caching: enable_caching })
        end
      end

      def index(params: {}, filters: {}, enable_caching: false)
        @client.with_response(Responses::HateoasEnumerableResponse) do
          @client.get(@url, params: params.merge(filters), options: { enable_caching: enable_caching })
        end
      end

      def update(id=nil, params)
        @client.with_response(Responses::HateoasResponse) do
          @client.patch(@url.gsub('{id}', id.to_s), body: params)
        end
      end

      def destroy(id=nil)
        # no response wrapping as DELETE is supposed to 204.
        @client.delete(@url.gsub('{id}', id.to_s))
      end
    end
  end
end
