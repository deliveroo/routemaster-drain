require 'routemaster/api_client'

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

      def show(id=nil)
        @client.get(@url.gsub('{id}', id.to_s))
      end

      def index
        @client.get(@url)
      end

      def update(id=nil, params)
        @client.patch(@url.gsub('{id}', id.to_s), body: params)
      end
    end
  end
end
