module Routemaster
  class CacheKey
    PREFIX = 'cache:'.freeze

    def self.url_key(url)
      "#{PREFIX}#{url}"
    end
  end
end
