[![Build Status](https://github.com/Alamofire/Firewalk/workflows/Firewalk%20CI/badge.svg?branch=master)](https://github.com/Alamofire/Firewalk/actions)

Firewalk is an HTTP test server written in Swift using Vapor.

- [Features](#features)
- [Requirements](#requirements)
- [Communication](#communication)
- [Installation](#installation)
- [License](#license)

## Features
Firewalk implements a subset of the [httpbin.org](https://httpbin.org) test server while adding additional features.

Every route is served on three ports:

| Port | Option | Environment variable | Serves |
| --- | --- | --- | --- |
| `8080` | `--port` | `FIREWALK_PORT` | HTTP/1.1 |
| `8443` | `--tls-port` | `FIREWALK_TLS_PORT` | HTTP/1.1 and HTTP/2 over TLS, with a self-signed certificate generated at launch and available from `/tls/certificate` |
| `8444` | `--expired-tls-port` | `FIREWALK_EXPIRED_TLS_PORT` | HTTP/1.1 and HTTP/2 over TLS, with an expired certificate issued through two intermediate CAs by an untrusted root, like expired.badssl.com |

## Usage
Run `firewalk`, optionally with these options, or their environment variables. An option given on the command line
overrides its environment variable.

| Option | Environment variable | Default | |
| --- | --- | --- | --- |
| `--hostname` | `FIREWALK_HOSTNAME` | `127.0.0.1` | The address to listen on. |
| `--port`, `--tls-port`, `--expired-tls-port` | See above | See above | The ports, which must differ. |
| `--max-body-size` | `FIREWALK_MAX_BODY_SIZE` | `100000000` | The largest request body accepted, in bytes or with a `kb`, `mb`, or `gb` suffix. |
| `--backlog` | `FIREWALK_BACKLOG` | `4096` | How many connections each port queues before accepting them. The OS may lower it, with `kern.ipc.somaxconn` on macOS. |
| `--connections-per-tick` | `FIREWALK_CONNECTIONS_PER_TICK` | `1024` | The most connections accepted at once by each event loop. |
| `--log-level` | `FIREWALK_LOG_LEVEL` | `info` for debug builds, `critical` otherwise | The minimum level logged. |

`firewalk --help` lists them too.

## Requirements
- Binaries:
	- Firewalk releases provide binaries for macOS 26+.
- Development:
	- Swift 6.4+.
	- Firewalk uses the [Vapor framework](https://vapor.codes) and so should be compatible various supported Swift platforms.

## Communication
- Bugs and features requests should be created here on GitHub.
- Questions about functionality or development should be posted on [Alamofire's Swift forum](https://forums.swift.org/c/related-projects/alamofire/37).

## Installation
Firewalk binaries can be installed through Homebrew.
```bash
$ brew install alamofire/alamofire/firewalk
```

## License
Firewalk is released under the MIT license. [See LICENSE](https://github.com/Alamofire/Firewalk/blob/master/LICENSE) for details.
