module Routemaster
  class CacheKeys
    attr_reader :url

    KEY_TEMPLATE = 'cache:{url}'

    def initialize(url)
      @url = url
    end

    def url_key
      KEY_TEMPLATE.gsub('{url}', @url)
    end
  end
end
