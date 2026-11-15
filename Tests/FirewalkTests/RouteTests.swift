//
//  RouteTests.swift
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
import Dependencies
import Testing
import VaporTesting

@Suite(.dependency(\.continuousClock, ImmediateClock()))
struct RouteTests {
    @Test(arguments: ["bytes/-1", "manyBytes/-1", "download/-10", "stream/0", "redirect/0"])
    func `invalid counts are a bad request`(path: String) async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, path) { response in
                #expect(response.status == .badRequest)
            }
        }
    }

    @Test
    func `stream repeats the whole reply on every line`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "stream/3") { response in
                let lines = response.body.string.split(separator: "\n", omittingEmptySubsequences: false)
                #expect(lines.count == 3)
                for line in lines {
                    #expect(throws: Never.self) { try JSONDecoder().decode(Reply.self, from: Data(line.utf8)) }
                }
            }
        }
    }

    @Test(arguments: [("bytes=0-99", "bytes 0-99/1000", 100),
                      ("bytes=900-", "bytes 900-999/1000", 100),
                      ("bytes=-100", "bytes 900-999/1000", 100),
                      ("bytes=990-2000", "bytes 990-999/1000", 10)])
    func `download serves the requested range`(range: String, contentRange: String, length: Int) async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "download/1000", headers: ["Range": range]) { response in
                #expect(response.status == .partialContent)
                #expect(response.headers.first(name: .contentRange) == contentRange)
                #expect(response.body.readableBytes == length)
            }
        }
    }

    @Test
    func `download rejects a range past its end`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "download/1000", headers: ["Range": "bytes=1000-"]) { response in
                #expect(response.status == .rangeNotSatisfiable)
                #expect(response.headers.first(name: .contentRange) == "bytes */1000")
            }
        }
    }

    @Test(arguments: ["bytes=0-1, 5-6", "bytes=9-1"])
    func `download serves everything for ranges it doesn't support`(range: String) async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "download/100", headers: ["Range": range]) { response in
                #expect(response.status == .ok)
                #expect(response.body.readableBytes == 100)
            }
        }
    }

    @Test
    func `download's Last-Modified is a valid HTTP date`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "download/10", headers: ["Range": "bytes=0-1"]) { response in
                #expect(response.headers.first(name: .lastModified) == "Mon, 01 Jan 2001 00:00:00 GMT")
            }
        }
    }

    @Test
    func `byte ranges follow RFC 9110`() {
        #expect(ByteRange(nil, length: 10) == .whole)
        #expect(ByteRange(.init(unit: .bytes, ranges: [.start(value: 0)]), length: 0) == .unsatisfiable)
        #expect(ByteRange(.init(unit: .bytes, ranges: [.tail(value: 0)]), length: 10) == .unsatisfiable)
        #expect(ByteRange(.init(unit: .bytes, ranges: [.tail(value: 20)]), length: 10) == .satisfiable(0...9))
        #expect(ByteRange(.init(unit: .bytes, ranges: [.within(start: 3, end: 3)]), length: 10) == .satisfiable(3...3))
    }

    @Test
    func `successful status responses are JSON`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "status/200") { response in
                #expect(response.headers.contentType == .json)
                try #expect(response.reply().url.hasSuffix("/status/200"))
            }
        }
    }

    @Test
    func `response URLs use the request's host`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "get", headers: ["Host": "example.com:1234"]) { response in
                try #expect(response.reply().url == "http://example.com:1234/get")
            }
            try await app.testing().test(.GET, "redirect/2", headers: ["Host": "example.com:1234"]) { response in
                #expect(response.headers.first(name: .location) == "http://example.com:1234/redirect/1")
            }
            try await app.testing().test(.GET, "status/301", headers: ["Host": "example.com:1234"]) { response in
                #expect(response.headers.first(name: .location) == "http://example.com:1234/get")
            }
        }
    }

    @Test(arguments: ["response-headers?X-Test=a%0D%0AInjected:%20yes",
                      "response-headers?bad%20name=x",
                      "cache?Cache-Control=a%0AInjected:%20yes",
                      "redirect-to?url=http://example.com/%0D%0AInjected:%20yes"])
    func `headers copied from requests can't split responses`(path: String) async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, path) { response in
                #expect(response.status == .badRequest)
                #expect(response.headers.first(name: "Injected") == nil)
            }
        }
    }

    @Test
    func `valid headers copied from requests are kept`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "response-headers?X-Test=a%09b") { response in
                #expect(response.status == .ok)
                #expect(response.headers.first(name: "X-Test") == "a\tb")
            }
        }
    }

    @Test
    func `download body has its full length`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "download/1000") { response in
                #expect(response.status == .ok)
                #expect(response.body.readableBytes == 1000)
                #expect(Set(response.body.readableBytesView).count == 1)
            }
        }
    }

    @Test(arguments: Image.allCases)
    func `every image decodes`(image: Image) async throws {
        #expect(!image.data.isEmpty)
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "image/\(image.rawValue)") { response in
                #expect(response.status == .ok)
                #expect(response.body.readableBytes == image.data.count)
            }
        }
    }

    @Test
    func `cache sets an older date on alternate requests`() async throws {
        try await withApp(configure: configure) { app in
            var dates: [String?] = []
            for _ in 0..<3 {
                try await app.testing().test(.GET, "cache?Cache-Control=no-cache") { response in
                    dates.append(response.headers.first(name: .date))
                }
            }

            let now = Date()
            let ages = dates.map { $0.flatMap(Date.init(rfc1123:)).map { now.timeIntervalSince($0) } }
            #expect(ages[0].map { $0 >= 4 } == true)
            #expect(ages[1].map { $0 < 4 } ?? true)
            #expect(ages[2].map { $0 >= 4 } == true)
        }
    }

    @Test
    func `version reports the current version and its components`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "version") { response in
                #expect(response.status == .ok)
                let reply = try response.content.decode(VersionReply.self)
                #expect(reply.version == Firewalk.version)
                #expect("\(reply.major).\(reply.minor).\(reply.patch)" == Firewalk.version)
            }
        }
    }
}
