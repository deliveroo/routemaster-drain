require 'redis'
require 'spec/support/uses_dotenv'
require 'routemaster/config'

module RspecSupportUsesRedis
  def uses_redis
    uses_dotenv

    before { Routemaster::Config.cache_redis.flushdb }
    before { Routemaster::Config.drain_redis.flushdb }
  end
end

RSpec.configure { |c| c.extend RspecSupportUsesRedis }
