redis.call('HMSET', KEYS[1], ARGV[1], ARGV[2], ARGV[3], ARGV[4], ARGV[5], ARGV[6]);
redis.call('EXPIRE', KEYS[1], ARGV[7]);
