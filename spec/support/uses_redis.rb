require 'redis'
require 'spec/support/uses_dotenv'
require 'routemaster/config'

module RspecSupportUsesRedis
  def uses_redis
    uses_dotenv

    let(:redis) { Routemaster::Config.drain_redis }
    before { Routemaster::Config.cache_redis.redis.flushdb }
    before { Routemaster::Config.drain_redis.redis.flushdb }
  end
end

RSpec.configure { |c| c.extend RspecSupportUsesRedis }
