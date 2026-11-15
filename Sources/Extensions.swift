//
//  Extensions.swift
//
//  Copyright (c) 2020-2026 Alamofire Software Foundation (http://alamofire.org/)
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

import Vapor

extension Vapor.Request: Vapor.Authenticatable {}

extension Request {
    var isAuthenticated: Bool {
        auth.has(Request.self)
    }
}

extension Application {
    @discardableResult
    func on(_ methods: [HTTPMethod],
            _ path: PathComponent...,
            body: HTTPBodyStreamStrategy = .collect,
            use closure: @escaping @Sendable (Request) throws -> some ResponseEncodable) -> [Route] {
        methods.map { on($0, path, body: body, use: closure) }
    }

    @discardableResult
    func onMethods(_ methods: [HTTPMethod],
                   body: HTTPBodyStreamStrategy = .collect,
                   use closure: @escaping @Sendable (Request) throws -> some ResponseEncodable) -> [Route] {
        methods.map { on($0, .constant($0.rawValue.lowercased()), body: body, use: closure) }
    }

    @discardableResult
    func on(_ methods: [HTTPMethod],
            _ path: PathComponent...,
            body: HTTPBodyStreamStrategy = .collect,
            use closure: @escaping @Sendable (Request) async throws -> some AsyncResponseEncodable) -> [Route] {
        methods.map { on($0, path, body: body, use: closure) }
    }
}

extension RoutesBuilder {
    @discardableResult
    func on(_ methods: [HTTPMethod],
            _ path: PathComponent...,
            body: HTTPBodyStreamStrategy = .collect,
            use closure: @escaping @Sendable (Request) throws -> some ResponseEncodable) -> [Route] {
        methods.map { on($0, path, body: body, use: closure) }
    }

    @discardableResult
    func on(_ methods: [HTTPMethod],
            _ path: PathComponent...,
            body: HTTPBodyStreamStrategy = .collect,
            use closure: @escaping @Sendable (Request) async throws -> some AsyncResponseEncodable) -> [Route] {
        methods.map { on($0, path, body: body, use: closure) }
    }
}

extension Parameters {
    subscript<T>(_ name: String, as _: T.Type = T.self) -> T? where T: LosslessStringConvertible {
        `get`(name)
    }
}

extension Request {
    /// The scheme, host, and port clients use to reach this server, for URLs in responses. It uses the request's `Host`,
    /// which is reachable even when the server listens on an address like `0.0.0.0`.
    var baseURL: String {
        let configuration = application.http.server.configuration
        let scheme = configuration.tlsConfiguration == nil ? "http" : "https"
        let host = headers.first(name: .host) ?? "\(configuration.hostname):\(configuration.port)"

        return "\(scheme)://\(host)"
    }
}

/// Rejects responses whose headers aren't valid HTTP with a `400`. Routes like `/response-headers` and `/redirect-to`
/// copy request input into headers, and Vapor's server pipeline doesn't validate outbound headers, so a CR or LF there
/// would otherwise split the response.
struct ResponseHeaderValidationMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let response = try await next.respond(to: request)
        guard response.headers.allSatisfy({ Self.isValidName($0.name) && Self.isValidValue($0.value) }) else {
            return Response(status: .badRequest)
        }

        return response
    }

    /// A token, per RFC 9110.
    static func isValidName(_ name: String) -> Bool {
        !name.isEmpty && name.utf8.allSatisfy { byte in
            switch byte {
            case UInt8(ascii: "0")...UInt8(ascii: "9"), UInt8(ascii: "a")...UInt8(ascii: "z"), UInt8(ascii: "A")...UInt8(ascii: "Z"):
                true
            default:
                "!#$%&'*+-.^_`|~".utf8.contains(byte)
            }
        }
    }

    /// Without the control characters RFC 9110 forbids, other than horizontal tab.
    static func isValidValue(_ value: String) -> Bool {
        value.utf8.allSatisfy { byte in byte == UInt8(ascii: "\t") || (byte >= 0x20 && byte != 0x7F) }
    }
}
