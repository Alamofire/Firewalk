# Change Log

All notable changes to this project will be documented in this file.
`Firewalk` adheres to [Semantic Versioning](https://semver.org/).

#### 0.x Releases

- `0.x` Releases - [0.1.0](#010) | [0.2.0](#020) | [0.3.0](#030) | [0.4.0](#040) | [0.5.0](#050) | [0.6.0](#060) | 
    [0.6.1](#061) | [0.7.0](#070) | [0.8.0](#080) | [0.8.1](#081) | [0.8.2](#082) | [0.8.3](#083) | [0.9.0](#090) | 
    [0.9.1](#091) | [0.10.0](#0100) | [0.10.1](#0101) | [0.10.2](#0102) | [0.10.3](#01003) | [0.10.4](#01004) | 
    [0.11.0](#0110) | [0.12.3](#0123) | [0.13.0](#0130) | [0.14.0](#0140) | [0.15.0](#0150) | [0.16.0](#0160)

---

## [0.16.0](https://github.com/Alamofire/Firewalk/releases/tag/0.16.0)

Released on 2026-11-15.

#### Added

- TLS server on port `8444` (configurable with `--expired-tls-port` or `FIREWALK_EXPIRED_TLS_PORT`) presenting an expired `localhost` and
  `127.0.0.1` certificate, issued through two intermediate CAs by an untrusted root, as a local replacement for
  expired.badssl.com.
  - Added by [Jon Shier](https://github.com/jshier) in PR [#46](https://github.com/Alamofire/Firewalk/pull/46).
- HTTP digest authentication on `/digest-auth/{qop}/{user}/{passwd}/{algorithm}/{staleAfter}`, replacing the redirect
  to httpbin.org. It supports `auth` and `auth-int`, the `MD5`, `MD5-sess`, `SHA-256`, and `SHA-256-sess` algorithms,
  hashed and RFC 8187 encoded usernames, `stale=true` for nonces past their five minute lifetime or `staleAfter` uses,
  and rejects repeated `nc` values.
  - Added by [Jon Shier](https://github.com/jshier) in PR [#46](https://github.com/Alamofire/Firewalk/pull/46).
- Command line options, with matching environment variables, for the hostname, each port, maximum body size, listen
  backlog, connections accepted per event loop tick, and log level. See `firewalk --help`.
  - Added by [Jon Shier](https://github.com/jshier) in PR [#46](https://github.com/Alamofire/Firewalk/pull/46).
- `/brotli`, `/gzip`, and `/deflate` served locally, replacing the redirects to httpbin.org. `gzip` and `deflate` use
  the system's zlib on every platform. Brotli uses Apple's Compression framework, so other platforms respond to
  `/brotli` with `501 Not Implemented`.
  - Added by [Jon Shier](https://github.com/jshier) in PR [#46](https://github.com/Alamofire/Firewalk/pull/46).
- `/version`, returning Firewalk's version and its major, minor, and patch components, so clients can check that
  Firewalk supports the routes and behaviors they use. `firewalk --version` prints it too.
  - Added by [Jon Shier](https://github.com/jshier) in PR [#46](https://github.com/Alamofire/Firewalk/pull/46).

#### Updated

- Command line handling to use Swift Argument Parser. Vapor's `serve` command and its `--env` and `--log` arguments
  are no longer accepted; use the options above instead.
  - Updated by [Jon Shier](https://github.com/jshier) in PR [#46](https://github.com/Alamofire/Firewalk/pull/46).
- Minimum macOS version to 26, so release binaries use the OS's Swift runtime, including `Span`, rather than needing
  `libswiftCompatibilitySpan.dylib` alongside them, and can use `Mutex`.
  - Updated by [Jon Shier](https://github.com/jshier) in PR [#46](https://github.com/Alamofire/Firewalk/pull/46).
- Minimum Swift version to 6.4, enforced when building.
  - Updated by [Jon Shier](https://github.com/jshier) in PR [#46](https://github.com/Alamofire/Firewalk/pull/46).

#### Fixed

- `/websocket` ping counting, which could miss or repeat the close after the last ping when pings arrived together.
  - Fixed by [Jon Shier](https://github.com/jshier) in PR [#46](https://github.com/Alamofire/Firewalk/pull/46).
- Crashes from negative counts in `/bytes`, `/manyBytes`, `/download`, and `/websocket/payloads`.
  - Fixed by [Jon Shier](https://github.com/jshier) in PR [#46](https://github.com/Alamofire/Firewalk/pull/46).
- `/stream` returning one reply followed by empty lines.
  - Fixed by [Jon Shier](https://github.com/jshier) in PR [#46](https://github.com/Alamofire/Firewalk/pull/46).
- `/download` ranges, which returned one byte too few from the wrong offset, and `Content-Range` values, which now end
  at the last byte and include the total length. Requests for several ranges now receive the whole body.
  - Fixed by [Jon Shier](https://github.com/jshier) in PR [#46](https://github.com/Alamofire/Firewalk/pull/46).
- `/download`'s `Last-Modified` using a 12 hour clock.
  - Fixed by [Jon Shier](https://github.com/jshier) in PR [#46](https://github.com/Alamofire/Firewalk/pull/46).
- Response URLs and redirect locations using the listening address, such as `0.0.0.0`, rather than the request's host.
  - Fixed by [Jon Shier](https://github.com/jshier) in PR [#46](https://github.com/Alamofire/Firewalk/pull/46).
- `/status` 2xx responses missing their JSON `Content-Type`.
  - Fixed by [Jon Shier](https://github.com/jshier) in PR [#46](https://github.com/Alamofire/Firewalk/pull/46).
- WebSocket subprotocol selection for `Sec-WebSocket-Protocol` values without spaces after commas.
  - Fixed by [Jon Shier](https://github.com/jshier) in PR [#46](https://github.com/Alamofire/Firewalk/pull/46).
- Response splitting through routes that copy request input into headers, like `/response-headers`, `/cache`, and
  `/redirect-to`. Responses with invalid headers are now replaced with a `400 Bad Request`.
  - Fixed by [Jon Shier](https://github.com/jshier) in PR [#46](https://github.com/Alamofire/Firewalk/pull/46).
- Startup crashes when Firewalk is built with Thread Sanitizer.
  - Fixed by [Jon Shier](https://github.com/jshier) in PR [#46](https://github.com/Alamofire/Firewalk/pull/46).

---

## [0.15.0](https://github.com/Alamofire/Firewalk/releases/tag/0.15.0)

Released on 2026-11-14.

#### Added

- TLS server on port `8443` (configurable with `FIREWALK_TLS_PORT`) offering HTTP/1.1 and HTTP/2, using a self-signed
  `localhost` certificate available from `/tls/certificate`.
  - Added by [Jon Shier](https://github.com/jshier) in PR [#45](https://github.com/Alamofire/Firewalk/pull/45).
- `etag`, `noLastModified`, and `noAcceptRanges` parameters to `/download`.
  - Added by [Jon Shier](https://github.com/jshier) in PR [#45](https://github.com/Alamofire/Firewalk/pull/45).
- `pongDelay` and `drop` parameters to `/websocket` routes.
  - Added by [Jon Shier](https://github.com/jshier) in PR [#45](https://github.com/Alamofire/Firewalk/pull/45).

#### Updated

- Route implementations to use Swift concurrency rather than `EventLoopFuture`s.
  - Updated by [Jon Shier](https://github.com/jshier) in PR [#45](https://github.com/Alamofire/Firewalk/pull/45).
- Maximum body size and connection handling to better support parallel test suites.
  - Updated by [Jon Shier](https://github.com/jshier) in PR [#45](https://github.com/Alamofire/Firewalk/pull/45).
- Minimum macOS version to 13, dependencies, and CI to Xcode 27.2 and Swift 6.4.
  - Updated by [Jon Shier](https://github.com/jshier) in PR [#45](https://github.com/Alamofire/Firewalk/pull/45).

#### Fixed

- `/download` handling of invalid and unsatisfiable `Range` requests.
  - Fixed by [Jon Shier](https://github.com/jshier) in PR [#45](https://github.com/Alamofire/Firewalk/pull/45).

---

## [0.14.0](https://github.com/Alamofire/Firewalk/releases/tag/0.14.0)

Released on 2026-09-13.

#### Updated

- `/websocket` handling to be more reliable and allow for more delay injection.
  - Added by [Jon Shier](https://github.com/jshier) in PR [#43](https://github.com/Alamofire/Firewalk/pull/43).

---

## [0.13.0](https://github.com/Alamofire/Firewalk/releases/tag/0.13.0)

Released on 2026-04-26.

#### Added

- Configurable `delay` parameter to `chunked` and `payloads`.
  - Added by [Jon Shier](https://github.com/jshier) in PR [#42](https://github.com/Alamofire/Firewalk/pull/42).

---

## [0.12.3](https://github.com/Alamofire/Firewalk/releases/tag/0.12.3)

Released on 2026-04-24.

#### Updated

- Timing of byte responses.
  - Updated by [Jon Shier](https://github.com/jshier) in PR [#41](https://github.com/Alamofire/Firewalk/pull/41).

---

## [0.11.0](https://github.com/Alamofire/Firewalk/releases/tag/0.11.0)

Released on 2024-09-28.

#### Updated

- Swift 6 compatibility and dependencies.
  - Updated by [Jon Shier](https://github.com/jshier) in PR [#37](https://github.com/Alamofire/Firewalk/pull/37).

---

## [0.10.4](https://github.com/Alamofire/Firewalk/releases/tag/0.10.4)

Released on 2023-01-27.

#### Updated

- Dependencies.
  - Updated by [Jon Shier](https://github.com/jshier) in PR [#36](https://github.com/Alamofire/Firewalk/pull/36).

## [0.10.3](https://github.com/Alamofire/Firewalk/releases/tag/0.10.3)

Released on 2023-11-07.

#### Fixed

- Stall when failing an HTTP upgrade.
  - Fixed by [Jon Shier](https://github.com/jshier) in PR [#34](https://github.com/Alamofire/Firewalk/pull/34).

## [0.10.2](https://github.com/Alamofire/Firewalk/releases/tag/0.10.2)

Released on 2023-10-10.

#### Updated

- Dependencies and formatting.
  - Updated by [Jon Shier](https://github.com/jshier) in PR [#33](https://github.com/Alamofire/Firewalk/pull/33).

## [0.10.1](https://github.com/Alamofire/Firewalk/releases/tag/0.10.1)

Released on 2023-08-18.

#### Updated

- Chunk delay in streaming endpoints.
  - Updated by [Jon Shier](https://github.com/jshier) in PR [#31](https://github.com/Alamofire/Firewalk/pull/31).

## [0.10.0](https://github.com/Alamofire/Firewalk/releases/tag/0.10.0)

Released on 2023-08-03.

#### Added

- Support for JPEG XL images.
  - Added by [Jon Shier](https://github.com/jshier) in PR [#29](https://github.com/Alamofire/Firewalk/pull/29).

---

## [0.9.1](https://github.com/Alamofire/Firewalk/releases/tag/0.9.1)

Released on 2023-03-15.

#### Added

- Support for request decompression.
  - Added by [Jon Shier](https://github.com/jshier) in PR [#26](https://github.com/Alamofire/Firewalk/pull/28).

## [0.9.0](https://github.com/Alamofire/Firewalk/releases/tag/0.9.0)

Released on 2023-02-21.

#### Added

- `websocket/ping` endpoint.
  - Fixed by [Jon Shier](https://github.com/jshier) in PR [#26](https://github.com/Alamofire/Firewalk/pull/27).

---

## [0.8.3](https://github.com/Alamofire/Firewalk/releases/tag/0.8.3)

Released on 2022-12-10.

#### Fixed

- Crash in streamed download responses.
  - Fixed by [Jon Shier](https://github.com/jshier) in PR [#26](https://github.com/Alamofire/Firewalk/pull/26).

## [0.8.2](https://github.com/Alamofire/Firewalk/releases/tag/0.8.2)

Released on 2022-11-27.

#### Added

- AVIF image response support.
  - Updated by [Jon Shier](https://github.com/jshier) in PR [#23](https://github.com/Alamofire/Firewalk/pull/23).

## [0.8.1](https://github.com/Alamofire/Firewalk/releases/tag/0.8.1)

Released on 2022-09-10.

#### Updated

- Dependencies, added Xcode 14 requirement.
  - Updated by [Jon Shier](https://github.com/jshier) in PR [#22](https://github.com/Alamofire/Firewalk/pull/22).

## [0.8.0](https://github.com/Alamofire/Firewalk/releases/tag/0.8.0)

Released on 2022-04-23.

#### Added

- `cache` endpoint for Cache-Control testing.
  - Added by [Jon Shier](https://github.com/jshier) in PR [#20](https://github.com/Alamofire/Firewalk/pull/20).

---

## [0.7.0](https://github.com/Alamofire/Firewalk/releases/tag/0.7.0)

Released on 2022-02-05.

#### Added

- `infinite` and `upload` endpoints.
  - Added by [Jon Shier](https://github.com/jshier) in PR [#18](https://github.com/Alamofire/Firewalk/pull/18).

#### Update

- Packages and package layout for Swift 5.5 and executable target.
  - Updated by [Jon Shier](https://github.com/jshier) in PR [#18](https://github.com/Alamofire/Firewalk/pull/18).

---

## [0.6.1](https://github.com/Alamofire/Firewalk/releases/tag/0.6.1)

Released on 2021-05-22.

#### Added

- Dynamic delay for websocket closings.
  - Added by [Jon Shier](https://github.com/jshier) in PR [#15](https://github.com/Alamofire/Firewalk/pull/15).

## [0.6.0](https://github.com/Alamofire/Firewalk/releases/tag/0.6.0)

Released on 2021-05-22.

#### Fixed

- Reliability of `websocket` endpoints for `URLSessionWebSocketTask` tests.
  - Added by [Jon Shier](https://github.com/jshier) in PR [#13](https://github.com/Alamofire/Firewalk/pull/13).

---

## [0.5.0](https://github.com/Alamofire/Firewalk/releases/tag/0.5.0)

Released on 2021-04-03.

#### Added

- Various image types to the `image/<type>` endpoint.
  - Added by [Jon Shier](https://github.com/jshier) in PR [#11](https://github.com/Alamofire/Firewalk/pull/11).

---

## [0.4.0](https://github.com/Alamofire/Firewalk/releases/tag/0.4.0)

Released on 2021-03-06.

#### Added

- `download` endpoint.
  - Added by [Jon Shier](https://github.com/jshier) in PR [#9](https://github.com/Alamofire/Firewalk/pull/9).

---

## [0.3.0](https://github.com/Alamofire/Firewalk/releases/tag/0.3.0)

Released on 2021-01-31.

#### Added

- Additional `websocket` endpoints.
  - Added by [Jon Shier](https://github.com/jshier) in PR [#7](https://github.com/Alamofire/Firewalk/pull/7).
- Support for universal release builds.
  - Added by [Jon Shier](https://github.com/jshier) in PR [#7](https://github.com/Alamofire/Firewalk/pull/7).

---

## [0.2.0](https://github.com/Alamofire/Firewalk/releases/tag/0.2.0)

Released on 2020-12-31.

#### Added

- Compression endpoints, which currently forward to HTTPBin.
- Response code parameter to `redirect-to` endpoint.

---

## [0.1.0](https://github.com/Alamofire/Firewalk/releases/tag/0.1.0)

Released on 2020-08-22.

- Initial Firewalk release.
