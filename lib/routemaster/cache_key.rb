module Routemaster
  class CacheKey
    def self.url_key(url)
      "cache:#{url}"
    end
  end
end
