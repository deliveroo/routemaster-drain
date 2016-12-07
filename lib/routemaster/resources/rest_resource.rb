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

      def show
        @client.get(@url)
      end

      def index
        @client.get(@url)
      end
    end
  end
end
