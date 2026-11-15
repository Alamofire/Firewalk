//
//  SettingsTests.swift
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

@testable import firewalk
import ArgumentParser
import Testing
import Vapor

struct SettingsTests {
    @Test
    func `defaults apply without options or environment variables`() throws {
        let settings = try Firewalk.parse([]).settings(environment: [:])

        #expect(settings == .default)
    }

    @Test
    func `environment variables apply without options`() throws {
        let environment = ["FIREWALK_HOSTNAME": "0.0.0.0",
                           "FIREWALK_PORT": "9080",
                           "FIREWALK_TLS_PORT": "9443",
                           "FIREWALK_EXPIRED_TLS_PORT": "9444",
                           "FIREWALK_MAX_BODY_SIZE": "2mb",
                           "FIREWALK_BACKLOG": "128",
                           "FIREWALK_CONNECTIONS_PER_TICK": "64",
                           "FIREWALK_LOG_LEVEL": "debug"]

        let settings = try Firewalk.parse([]).settings(environment: environment)

        #expect(settings == Settings(hostname: "0.0.0.0",
                                     port: 9080,
                                     tlsPort: 9443,
                                     expiredTLSPort: 9444,
                                     maxBodySize: 2 << 20,
                                     backlog: 128,
                                     connectionsPerTick: 64,
                                     logLevel: .debug))
    }

    @Test
    func `options override environment variables`() throws {
        let command = try Firewalk.parse(["--port", "7080", "--max-body-size", "512", "--log-level", "error"])

        let settings = try command.settings(environment: ["FIREWALK_PORT": "9080",
                                                          "FIREWALK_MAX_BODY_SIZE": "2mb",
                                                          "FIREWALK_LOG_LEVEL": "debug",
                                                          "FIREWALK_BACKLOG": "128"])

        #expect(settings.port == 7080)
        #expect(settings.maxBodySize == 512)
        #expect(settings.logLevel == .error)
        #expect(settings.backlog == 128)
    }

    @Test
    func `empty environment variables are ignored`() throws {
        let settings = try Firewalk.parse([]).settings(environment: ["FIREWALK_PORT": ""])

        #expect(settings.port == Settings.default.port)
    }

    @Test(arguments: [["FIREWALK_PORT": "http"],
                      ["FIREWALK_MAX_BODY_SIZE": "lots"],
                      ["FIREWALK_LOG_LEVEL": "loud"],
                      ["FIREWALK_PORT": "70000"],
                      ["FIREWALK_TLS_PORT": "8080"],
                      ["FIREWALK_BACKLOG": "0"],
                      ["FIREWALK_HOSTNAME": " "]])
    func `invalid environment variables are rejected`(environment: [String: String]) throws {
        #expect(throws: ValidationError.self) {
            try Firewalk.parse([]).settings(environment: environment)
        }
    }

    @Test(arguments: [["--port", "0"], ["--expired-tls-port", "8443"], ["--connections-per-tick", "0"]])
    func `invalid options are rejected when parsed`(arguments: [String]) {
        #expect(throws: (any Error).self) {
            try Firewalk.parse(arguments)
        }
    }

    @Test(arguments: [("1024", 1024), ("1kb", 1024), ("100 MB", 100 << 20), ("2gb", 2 << 30), ("0", 0)])
    func `byte sizes parse`(argument: String, bytes: Int) {
        #expect(ByteSize(argument: argument)?.bytes == bytes)
    }

    @Test(arguments: ["lots", "-1", "1tb", "kb", "1.5mb", "9999999999999gb"])
    func `invalid byte sizes are rejected`(argument: String) {
        #expect(ByteSize(argument: argument) == nil)
    }
}
