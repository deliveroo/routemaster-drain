### 2.3.3 (2017-01-13)

- Add #has? method on HateoasResponse of identifying resource without invocation

### 2.2.3 (2017-01-13)

- Fix 404 breaking CacheAndSweep job run

### 2.2.2 (2017-01-10)

- Fix logging for error responses:
  For unsuccessful responses rescue the raised error and
  send increment signal to metrics backend
- Add Telemetry support for requests and responses
- Add support for PATCH requests.
  Invalidate cached response (if any) on PATCH

### 2.0.0 (2016-12-14)

Major upgrade: the gem now includes a high-level HTTP API client.

- Request materialisation, JSON-HAL parsing, and hypermedia link traversal (#6)
- Surface HTTP errors as exceptions (#8)
- Various fixes (#7, #9, #10)
- Testing against multiple versions of Rails (#11)
