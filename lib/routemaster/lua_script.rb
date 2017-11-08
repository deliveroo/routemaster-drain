module Routemaster
  class LuaScript
    def initialize(name, redis = nil)
      @redis  = redis || Config.cache_redis
      @script = load_script(name).strip
      @digest = digest(@script)
    end

    def inspect
      "Luascript: #{@script}"
    end

    def load_script(name)
      File.read(File.join(File.dirname(__FILE__), '/lua/', "#{name}.lua"))
    end

    def digest(script)
      Digest::SHA1.hexdigest(script)
    end

    def run(*args)
      attempts = 0
      begin
        attempts += 1
        eval_script(*args)
      rescue Redis::CommandError => e
        load_into_redis
        raise e if attempts > 1
        retry
      end
    end

    def eval_script(*args)
      @redis.evalsha(@digest, *args)
    end

    def load_into_redis
      @redis.redis.script(:load, @script)
    end
  end
end
