local result = redis.call('HINCRBY', KEYS[1], ARGV[1], 1);
redis.call('EXPIRE', KEYS[1], ARGV[2]);
return result
