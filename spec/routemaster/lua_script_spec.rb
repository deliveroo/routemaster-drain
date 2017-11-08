require 'spec_helper'
require 'spec/support/uses_redis'
require 'routemaster/lua_script'
require 'json'

describe Routemaster::LuaScript do
  uses_redis
  context "when loading the increment and expire script" do
    before { Routemaster::Config.cache_redis.redis.script(:flush) }

    let(:lua_script) do
      described_class.new('increment_and_expire_h')
    end

    context "on first run" do
      it "performs a eval then a eval_sha" do
        expect(lua_script).to receive(:load_into_redis).and_call_original
        lua_script.run(['some_hash'], ['some_redis_key', 60])
      end

      it "increments a hvalue value" do
        Routemaster::Config.cache_redis.hincrby('some_hash', 'some_redis_key', 1)
        lua_script.run(['some_hash'], ['some_redis_key', 60])
        expect(Routemaster::Config.cache_redis.hget('some_hash','some_redis_key')).to eq "2"
        expect(Routemaster::Config.cache_redis.ttl('some_hash')).to eq 60
      end

      context "on the second run" do
        it "performs only a eval_sha" do
          lua_script.run(['some_hash'], ['some_redis_key', 60])
          expect(lua_script).not_to receive(:load_into_redis)
          lua_script.run(['some_hash'], ['some_redis_key', 60])
        end
      end
    end
  end
end
