//
//  Settings.swift
//
//  Copyright (c) 2026 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import ArgumentParser
import Vapor

/// How Firewalk's servers are configured.
struct Settings: Equatable, Sendable {
    static let `default` = Settings()

    var hostname = "127.0.0.1"
    var port = 8080
    var tlsPort = 8443
    var expiredTLSPort = 8444
    /// Large enough for the biggest upload tests, so oversized bodies aren't rejected with a 413 mid-upload.
    var maxBodySize = 100_000_000
    /// Test suites running in parallel open bursts of connections, which a deep listen queue and accepting many
    /// connections per event loop tick keep from being refused.
    var backlog = 4096
    var connectionsPerTick: UInt = 1024
    #if DEBUG
    var logLevel = Logger.Level.info
    #else
    var logLevel = Logger.Level.critical
    #endif

    func validate() throws {
        let ports = [("--port", port), ("--tls-port", tlsPort), ("--expired-tls-port", expiredTLSPort)]
        for (name, port) in ports where !(1...65_535).contains(port) {
            throw ValidationError("\(name) is \(port), but must be from 1 to 65535.")
        }
        guard Set(ports.map(\.1)).count == ports.count else {
            throw ValidationError("--port, --tls-port, and --expired-tls-port must all differ.")
        }
        guard !hostname.allSatisfy(\.isWhitespace) else { throw ValidationError("--hostname can't be empty.") }
        guard maxBodySize > 0 else { throw ValidationError("--max-body-size must be positive.") }
        guard backlog > 0 else { throw ValidationError("--backlog must be positive.") }
        guard connectionsPerTick > 0 else { throw ValidationError("--connections-per-tick must be positive.") }
    }
}

/// A byte count, written as a number of bytes or with a `kb`, `mb`, or `gb` suffix for multiples of 1024, like Vapor's
/// `ByteCount`, but rejecting invalid values rather than crashing.
struct ByteSize: Equatable, ExpressibleByArgument {
    let bytes: Int

    init(_ bytes: Int) {
        self.bytes = bytes
    }

    init?(argument: String) {
        let value = argument.lowercased().filter { !$0.isWhitespace }
        let shifts = ["kb": 10, "mb": 20, "gb": 30]
        let suffix = shifts.keys.first { value.hasSuffix($0) }
        guard let number = Int(suffix.map { String(value.dropLast($0.count)) } ?? value), number >= 0 else { return nil }

        let multiplier = 1 << (suffix.flatMap { shifts[$0] } ?? 0)
        let (bytes, overflow) = number.multipliedReportingOverflow(by: multiplier)
        guard !overflow else { return nil }

        self.bytes = bytes
    }
}

extension Logger.Level: @retroactive ExpressibleByArgument {}
