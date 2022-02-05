//
//  Extensions.swift
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

import Vapor

extension Request: Authenticatable {}

extension Request {
    var isAuthenticated: Bool {
        auth.has(Request.self)
    }
}

extension Application {
    @discardableResult
    func on<Response: ResponseEncodable>(_ methods: [HTTPMethod],
                                         _ path: PathComponent...,
                                         body: HTTPBodyStreamStrategy = .collect,
                                         use closure: @escaping (Request) throws -> Response) -> [Route] {
        methods.map { on($0, path, body: body, use: closure) }
    }

    @discardableResult
    func onMethods<Response: ResponseEncodable>(_ methods: [HTTPMethod],
                                                body: HTTPBodyStreamStrategy = .collect,
                                                use closure: @escaping (Request) throws -> Response) -> [Route] {
        methods.map { on($0, .constant($0.rawValue.lowercased()), body: body, use: closure) }
    }
}

extension RoutesBuilder {
    @discardableResult
    func on<Response: ResponseEncodable>(_ methods: [HTTPMethod],
                                         _ path: PathComponent...,
                                         body: HTTPBodyStreamStrategy = .collect,
                                         use closure: @escaping (Request) throws -> Response) -> [Route] {
        methods.map { on($0, path, body: body, use: closure) }
    }
}

extension Parameters {
    subscript<T>(_ name: String, as _: T.Type = T.self) -> T? where T: LosslessStringConvertible {
        `get`(name)
    }
}

extension HTTPServer.Configuration {
    var address: String {
        let scheme = tlsConfiguration == nil ? "http" : "https"
        return "\(scheme)://\(hostname):\(port)"
    }
}
