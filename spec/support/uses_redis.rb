require 'redis'
require 'spec/support/uses_dotenv'

module RspecSupportUsesRedis
  def uses_redis
    uses_dotenv

    let(:redis) { Redis.new(url: ENV.fetch('REDIS_TEST_URL')) }
    before { redis.flushdb }
  end
end

RSpec.configure { |c| c.extend RspecSupportUsesRedis }
