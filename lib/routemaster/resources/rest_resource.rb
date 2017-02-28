require 'routemaster/api_client'
require 'routemaster/responses/hateoas_enumerable_response'

module Routemaster
  module Resources
    class RestResource
      attr_reader :url

      def initialize(url, client: nil)
        @url = url
        @client = client || Routemaster::APIClient.new(response_class: Responses::HateoasResponse)
      end

      def create(params)
        @client.post(@url, body: params)
      end

      def show(id=nil, enable_caching: true)
        @client.get(@url.gsub('{id}', id.to_s), options: { enable_caching: enable_caching })
      end

      def index(params: {}, filters: {}, enable_caching: false)
        @client.with_response(Responses::HateoasEnumerableResponse) do |client|
          client.get(@url, params: params.merge(filters), options: { enable_caching: enable_caching })
        end
      end

      def update(id=nil, params)
        @client.patch(@url.gsub('{id}', id.to_s), body: params)
      end

      def destroy(id=nil)
        @client.delete(@url.gsub('{id}', id.to_s))
      end
    end
  end
end
