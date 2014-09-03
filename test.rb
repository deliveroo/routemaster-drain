#!/usr/bin/env ruby


require 'rubygems'
require 'bundler/setup'
require 'dotenv'
require 'pry'
require 'routemaster/cache'
# require 'routemaster/client/openssl'


Dotenv.load
Routemaster::Config.cache_redis.flushdb
$url = 'https://blackhole.dev/api/widgets/123'
$cache = Routemaster::Cache.new

binding.pry
