//
//  AppTests.swift
//
//  Copyright (c) 2020 Alamofire Software Foundation (http://alamofire.org/)
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
import XCTVapor

final class AppTests: XCTestCase {
    func testGet() throws {
        // Given
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        var response: XCTHTTPResponse?
        var value: Reply?

        // When
        try app.test(.GET, "get", into: &response, decoding: &value)

        // Then
        XCTAssertEqual(response?.status, .ok)
        XCTAssertEqual(value?.url, "http://127.0.0.1:8080/get")
    }

    func testPost() throws {
        // Given
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        var response: XCTHTTPResponse?
        var value: Reply?

        // When
        try app.test(.POST, "post", into: &response, decoding: &value)

        // Then
        XCTAssertEqual(response?.status, .ok)
        XCTAssertEqual(value?.url, "http://127.0.0.1:8080/post")
    }

    func testGetWithQueryParameters() throws {
        // Given
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        var response: XCTHTTPResponse?
        var value: Reply?

        // When
        try app.test(.GET, "get?one=one&two=two", into: &response, decoding: &value)

        // Then
        XCTAssertEqual(response?.status, .ok)
        XCTAssertEqual(value?.url, "http://127.0.0.1:8080/get?one=one&two=two")
        XCTAssertEqual(value?.args, ["one": "one", "two": "two"])
    }

    func testPostWithBodyForm() throws {
        // Given
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        var response: XCTHTTPResponse?
        var value: Reply?

        // When
        try app.test(.GET, "get?one=one&two=two", into: &response, decoding: &value)

        // Then
        XCTAssertEqual(response?.status, .ok)
        XCTAssertEqual(value?.url, "http://127.0.0.1:8080/get?one=one&two=two")
        XCTAssertEqual(value?.args, ["one": "one", "two": "two"])
    }

    func testAllMethodQueries() throws {
        // Given
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        var response: XCTHTTPResponse?
        var value: Reply?

        // When
        let methods: [HTTPMethod] = [.GET, .POST, .DELETE, .PATCH, .PUT]
        for method in methods {
            try app.test(method, "/\(method.rawValue.lowercased())", into: &response, decoding: &value)

            // Then
            XCTAssertEqual(response?.status, .ok)
            XCTAssertEqual(value?.url, "http://127.0.0.1:8080/\(method.rawValue.lowercased())")
        }
    }

    func testPostWithFormBody() throws {
        // Given
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        var response: XCTHTTPResponse?
        var reply: Reply?

        var headers = HTTPHeaders()
        var body = app.allocator.buffer(capacity: 100)
        try URLEncodedFormEncoder().encode(["one": "one"], to: &body, headers: &headers)

        // When
        try app.test(.POST, "post", headers: headers, body: body, into: &response, decoding: &reply)

        // Then
        XCTAssertEqual(response?.status, .ok)
        XCTAssertEqual(reply?.form, ["one": "one"])
    }

    func testStatusCode() throws {
        // Given
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        var response: XCTHTTPResponse?

        // When
        try app.test(.GET, "status/401", into: &response)

        // Then
        XCTAssertEqual(response?.status, .unauthorized)
    }

    func testThatInvalidStatusCodeReturns400() throws {
        // Given
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        var response: XCTHTTPResponse?

        // When
        try app.test(.GET, "status/blah", into: &response)

        // Then
        XCTAssertEqual(response?.status, .badRequest)
    }

    func testThatBytesReturnsAppropriateLength() throws {
        // Given
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let expectedSize = 10
        var response: XCTHTTPResponse?

        // When
        try app.test(.GET, "bytes/\(expectedSize)", into: &response)

        // Then
        XCTAssertEqual(response?.status, .ok)
        XCTAssertEqual(response?.body.readableBytes, expectedSize)
    }

    func testThatInvalidBytesReturns400() throws {
        // Given
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        var response: XCTHTTPResponse?

        // When
        try app.test(.GET, "bytes/blah", into: &response)

        // Then
        XCTAssertEqual(response?.status, .badRequest)
    }

    func testThatXMLReturnsXML() throws {
        // Given
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        var response: XCTHTTPResponse?

        // When
        try app.test(.GET, "xml", into: &response)

        // Then
        XCTAssertEqual(response?.status, .ok)
        XCTAssertEqual(response?.body.getString(at: 0, length: 5), "<?xml")
    }

    func testThatIPReturnsOrigin() throws {
        // Given
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        var response: XCTHTTPResponse?
        var ipReply: IPReply?

        // When
        try app.test(.GET, "ip", into: &response, decoding: &ipReply)

        // Then
        XCTAssertEqual(response?.status, .ok)
    }

    func testThatBasicAuthWorkWithProperCredentials() throws {
        // Given
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let username = "user"
        let password = "pass"
        var headers = HTTPHeaders()
        headers.basicAuthorization = BasicAuthorization(username: username, password: password)
        var response: XCTHTTPResponse?
        var reply: Reply?

        // When
        try app.test(.GET, "basic-auth/\(username)/\(password)", headers: headers, into: &response, decoding: &reply)

        // Then
        XCTAssertEqual(response?.status, .ok)
        XCTAssertNotNil(reply)
    }

    func testThatBasicAuthFailsWithImproperCredentials() throws {
        // Given
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        var response: XCTHTTPResponse?

        // When
        try app.test(.GET, "basic-auth/user/pass", into: &response)

        // Then
        XCTAssertEqual(response?.status, .unauthorized)
    }

    func testThatRedirectToWorks() throws {
        // Given
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        var response: XCTHTTPResponse?

        // When
        try app.test(.GET, "redirect-to?url=URL", into: &response)

        // Then
        XCTAssertEqual(response?.status, .found)
        XCTAssertEqual(response?.headers.first(name: .location), "URL")
    }
}

extension XCTApplicationTester {
    @discardableResult
    func test(_ method: HTTPMethod,
              _ path: String,
              headers: HTTPHeaders = [:],
              body: ByteBuffer? = nil,
              file _: StaticString = #file,
              line _: UInt = #line,
              into response: inout XCTHTTPResponse?) throws -> XCTApplicationTester {
        try test(method, path, headers: headers, body: body) { response = $0 }
    }

    @discardableResult
    func test<T: Decodable>(_ method: HTTPMethod,
                            _ path: String,
                            headers: HTTPHeaders = [:],
                            body: ByteBuffer? = nil,
                            file _: StaticString = #file,
                            line _: UInt = #line,
                            into response: inout XCTHTTPResponse?,
                            decoding value: inout T?) throws -> XCTApplicationTester {
        try test(method, path, headers: headers, body: body) {
            response = $0
            value = try $0.body.getJSONDecodable(T.self, at: $0.body.readerIndex, length: $0.body.readableBytes)
        }
    }
}
