//
//  AppTests.swift
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
import Testing
import VaporTesting

struct AppTests {
    @Test
    func get() async throws {
        // Given
        try await withApp(configure: configure) { app in
            // When
            try await app.testing().test(.GET, "get") { response in
                // Then
                #expect(response.status == .ok)
                try #expect(response.reply().url == "http://127.0.0.1:8080/get")
            }
        }
    }

    @Test
    func post() async throws {
        // Given
        try await withApp(configure: configure) { app in
            // When
            try await app.testing().test(.POST, "post") { response in
                // Then
                #expect(response.status == .ok)
                try #expect(response.reply().url == "http://127.0.0.1:8080/post")
            }
        }
    }

    @Test
    func `get with query parameters`() async throws {
        // Given
        try await withApp(configure: configure) { app in
            // When
            try await app.testing().test(.GET, "get?one=one&two=two") { response in
                // Then
                #expect(response.status == .ok)
                let reply = try response.reply()
                #expect(reply.url == "http://127.0.0.1:8080/get?one=one&two=two")
                #expect(reply.args == ["one": "one", "two": "two"])
            }
        }
    }

    @Test
    func `all method queries`() async throws {
        // Given
        try await withApp(configure: configure) { app in
            // When
            let methods: [HTTPMethod] = [.GET, .POST, .DELETE, .PATCH, .PUT]
            for method in methods {
                try await app.testing().test(method, "\(method.rawValue.lowercased())") { response in
                    // Then
                    #expect(response.status == .ok)
                    try #expect(response.reply().url == "http://127.0.0.1:8080/\(method.rawValue.lowercased())")
                }
            }
        }
    }

    @Test
    func `post with form body`() async throws {
        // Given
        try await withApp(configure: configure) { app in
            // When
            var headers = HTTPHeaders()
            var body = app.allocator.buffer(capacity: 100)
            try URLEncodedFormEncoder().encode(["one": "one"], to: &body, headers: &headers)
            try await app.testing().test(.POST, "post", headers: headers, body: body) { response in
                // Then
                #expect(response.status == .ok)
                let reply = try response.reply()
                #expect(reply.url == "http://127.0.0.1:8080/post")
                #expect(reply.form == ["one": "one"])
            }
        }
    }

    @Test
    func `status code`() async throws {
        // Given
        try await withApp(configure: configure) { app in
            // When
            try await app.testing().test(.GET, "status/401") { response in
                // Then
                #expect(response.status == .unauthorized)
            }
        }
    }

    @Test
    func `that invalid status code returns400`() async throws {
        // Given
        // Given
        try await withApp(configure: configure) { app in
            // When
            try await app.testing().test(.GET, "status/blah") { response in
                // Then
                #expect(response.status == .badRequest)
            }
        }
    }

    @Test
    func `that bytes returns appropriate length`() async throws {
        // Given
        try await withApp(configure: configure) { app in
            // When
            let expectedSize = 10
            try await app.testing().test(.GET, "bytes/\(expectedSize)") { response in
                // Then
                #expect(response.status == .ok)
                #expect(response.body.readableBytes == expectedSize)
            }
        }
    }

    @Test
    func `that invalid bytes returns400`() async throws {
        // Given
        try await withApp(configure: configure) { app in
            // When
            try await app.testing().test(.GET, "bytes/blah") { response in
                // Then
                #expect(response.status == .badRequest)
            }
        }
    }

    @Test
    func `that XML returns XML`() async throws {
        // Given
        try await withApp(configure: configure) { app in
            // When
            try await app.testing().test(.GET, "xml") { response in
                // Then
                #expect(response.status == .ok)
                #expect(response.body.getString(at: 0, length: 5) == "<?xml")
            }
        }
    }

    @Test
    func `that IP returns origin`() async throws {
        // Given
        try await withApp(configure: configure) { app in
            // When
            try await app.testing().test(.GET, "ip") { response in
                // Then
                #expect(response.status == .ok)
                try #expect(response.decodeBody(as: IPReply.self).origin == "No IP Address.")
            }
        }
    }

    @Test
    func `that basic auth work with proper credentials`() async throws {
        // Given
        try await withApp(configure: configure) { app in
            // When
            let username = "user"
            let password = "pass"
            var headers = HTTPHeaders()
            headers.basicAuthorization = BasicAuthorization(username: username, password: password)
            try await app.testing().test(.GET, "basic-auth/\(username)/\(password)", headers: headers) { response in
                // Then
                #expect(response.status == .ok)
                try #expect(response.reply().url == "http://127.0.0.1:8080/basic-auth/\(username)/\(password)")
            }
        }
    }

    @Test
    func `that basic auth fails with improper credentials`() async throws {
        // Given
        try await withApp(configure: configure) { app in
            // When
            try await app.testing().test(.GET, "basic-auth/user/pass") { response in
                // Then
                #expect(response.status == .unauthorized)
            }
        }
    }

    @Test
    func `that redirect to works`() async throws {
        // Given
        try await withApp(configure: configure) { app in
            // When
            try await app.testing().test(.GET, "redirect-to?url=URL") { response in
                // Then
                #expect(response.status == .found)
                #expect(response.headers.first(name: .location) == "URL")
            }
        }
    }
}

extension TestingHTTPResponse {
    struct MissingBody: Error {}

    func decodeBody<Body: Decodable>(as type: Body.Type = Body.self) throws -> Body {
        guard let data = body.getData(at: body.readerIndex, length: body.readableBytes, byteTransferStrategy: .noCopy) else {
            throw MissingBody()
        }

        return try JSONDecoder().decode(Body.self, from: data)
    }

    func reply() throws -> Reply {
        try decodeBody(as: Reply.self)
    }
}
