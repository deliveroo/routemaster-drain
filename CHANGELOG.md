### HEAD

_A description of your awesome changes here!_

### 3.5.0 (2018-03-07)

Features:

- Raises more semantically correct error on 410

### 3.4.0 (2017-11-16)

Features:

- Raises error on 405 and 503

### 3.3.0 (2017-11-16)

Features:

- Adds a PUT request to the APIClient

### 3.2.0 (2017-11-10)

Features:

- Adds a circuit breaker to GET requests (#66)

### 3.1.0 (2017-11-02)

Features:

- Make retry-attempt-count and retry-methods configurable in APIClient.

### 3.0.3 (2017-09-21)

Bug fixes:

- Fixes a regression introduced in 3.0.1 where the APIClient auth data would not be populated under some conditions. (#65)

### 3.0.2 (2017-09-05)

Bug fixes:

- Fixes a condition where cache keys in Redis would not expire (#63)


### 3.0.1 (2017-08-08)

Bug fixes:

- Set middleware before adapter so Faraday is happy (#60)


### 3.0.0 (2017-06-22)

Breaking API changes

- Removes the `#with_response` API client method. (#54)

Bug fixes

- Remove state from api client for thread safety. (#54)


### 2.5.4 (2017-06-12)

Bug fixes

- Use thread pool executor instead of cached thread pool (#51)

### 2.5.3 (2017-06-12)

Features

- Allow to supply pre-initialized (distributed) Redis client objects to connect
  to the Drain Redis and the Cache Redis (#52)

### 2.5.2 (2017-05-11)

Bug fixes

- Bust the cache when the resource is not found (#48)

### 2.5.1 (2017-05-10)

Features:

- Adds the `Siphon` middleware  to `CacheBusting` drain (#45)

Bug fixes

- Sweep the dirty map if a resource is missing (#47)

### 2.5.0 (2017-04-11)

Features:

- Allow template urls to be defined in services (#38)
- Adds the `Siphon` middleware (#39, #44)
- Adds `CacheBusting` middleware (#40)

Bug fixes:

- Caching middleware always busts the cache on events - preventing stale events being cached in some circumstances (#40)

### 2.4.4 (2017-03-27)

Features:

- Optionally wrap the APIClient actions inside a Response class (#37)

### 2.4.3 (2017-03-22)

Bug fixes:

- Require 'rest_resource' further up in the file tree (#36)

### 2.4.2 (2017-03-21)

Bug fixes:

- APIClient#discover now memoizes the root response at class level (#35)

### 2.4.1 (2017-03-15)

Features:

- API Client now exposes promises instead of simple futures (#34)

### 2.4.0 (2017-03-03)

Features:

- Collection traversal API (#24)
- Permits disabling of response caching (#26)
- Use `Redis::Distributed` for caching (#27)

Bug fixes:

- Do not cache collection responses (#26)
- Fixes Sidekiq loading issue (#25)
- Concurrency issues when caching (#28)
- Ruby 2.4.0 compatibility (#31)

Other:

- Switches from `net-http-persistent` to `typhoeus` (#31)
- Switches from `ruby-thread` to `concurrent-ruby` (#31)


### 2.3.0 (2017-01-16)

Features:

- Adds `HateoasResponse#has?` to check for resource relations (#22)

Bug fixes:

- Fixes 404s breaking the `CacheAndSweep` job (#21)

### 2.2.2 (2017-01-10)

- Fix logging for error responses:
  For unsuccessful responses rescue the raised error and
  send increment signal to metrics backend (#15)
- Add Telemetry support for requests and responses (#16)
- Add support for PATCH requests. (#12)
  Invalidate cached response (if any) on PATCH

### 2.0.0 (2016-12-14)

Major upgrade: the gem now includes a high-level HTTP API client.

- Request materialisation, JSON-HAL parsing, and hypermedia link traversal (#6)
- Surface HTTP errors as exceptions (#8)
- Various fixes (#7, #9, #10)
- Testing against multiple versions of Rails (#11)
