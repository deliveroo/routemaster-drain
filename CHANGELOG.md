### 2.2.1 (2016-12-22)
Fix logging for error responses

- For unsuccessful responses rescue the raised error and
send increment signal to metrics backend

### 2.2.0 (2016-12-22)
Add Telemetry support for requests and responses

### 2.1.0 (2016-12-14)
Add support for PATCH requests

- Invalidate cached response (if any) on PATCH

### 2.0.0 (2016-12-14)

Major upgrade: the gem now includes a high-level HTTP API client.

- Request materialisation, JSON-HAL parsing, and hypermedia link traversal (#6)
- Surface HTTP errors as exceptions (#8)
- Various fixes (#7, #9, #10)
- Testing against multiple versions of Rails (#11)
