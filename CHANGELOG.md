Features:

- Allow template urls to be defined in services (#38)

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
