# Change Log

All notable changes to this project will be documented in this file.
`Firewalk` adheres to [Semantic Versioning](https://semver.org/).

#### 0.x Releases

- `0.x` Releases - [0.1.0](#010) | [0.2.0](#020) | [0.3.0](#030) | [0.4.0](#040) | [0.5.0](#050)
  [0.6.0](#060) | [0.6.1](#061) | [0.7.0](#070) | [0.8.0](#080) | [0.8.1](#081)
  [0.8.2](#082) | [0.8.3](#083) | [0.9.0](#090) | [0.9.1](#091) | [0.10.0](#0100) | [0.10.1](#0101)
  [0.10.2](#0102) | [0.10.3](#01003)

---

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
