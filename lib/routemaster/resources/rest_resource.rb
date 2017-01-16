require 'routemaster/api_client'
require 'routemaster/responses/enumerable_hateoas_response'

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

      def future_show(id=nil)
        @client.fget(@url.gsub('{id}', id.to_s))
      end

      def show(id=nil)
        @client.get(@url.gsub('{id}', id.to_s))
      end

      def index(params: {}, filters: {})
        params_and_filters = params.merge(filters)
        hateoas_response = if params_and_filters == {}
                             @client.get(@url)
                           else
                             @client.get(@url, params: params_and_filters)
                           end
        Responses::EnumerableHateoasResponse.new(hateoas_response)
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
