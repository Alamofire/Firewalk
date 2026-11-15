//
//  Methods.swift
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

import Dependencies
import Vapor

func createMethodRoutes(for app: Application) throws {
    @Dependency(\.continuousClock) var clock

    app.onMethods([.GET, .POST, .PUT, .PATCH, .DELETE], use: Reply.init(to:))

    app.on([.GET, .POST, .PUT, .PATCH, .DELETE], "delay", ":interval") { request async throws -> Reply in
        if let interval = request.parameters["interval", as: Int64.self], interval <= 10 {
            try await clock.sleep(for: .seconds(interval))
        }

        return try Reply(to: request)
    }

    app.on([.GET, .POST, .PUT, .PATCH, .DELETE], "status", ":code") { request -> Response in
        guard let code = request.parameters["code", as: Int.self] else { return Response(status: .badRequest) }

        switch code {
        case Int.min..<200:
            return Response(status: .badRequest)
        case 200..<300:
            if code == 204 || code == 205 {
                let response = Response(status: .init(statusCode: code))
                response.headers.contentType = nil
                return response
            } else {
                let reply = try Reply(to: request)
                let encodedReply = try JSONEncoder().encodeAsByteBuffer(reply, allocator: app.allocator)
                let response = Response(status: .init(statusCode: code), body: .init(buffer: encodedReply))
                response.headers.contentType = .json
                return response
            }
        case 300..<400:
            let response = Response(status: .init(statusCode: code))
            response.headers.replaceOrAdd(name: .location, value: "\(request.baseURL)/\(request.method.rawValue.lowercased())")
            return response
        default:
            let response = Response(status: code < 600 ? .init(statusCode: code) : .badRequest)
            // NIO stops parsing HTTP when an upgrade is detected, so close the connection.
            // Remove if NIO / Vapor fixes the issue.
            if request.headers.contains(name: .upgrade) {
                response.headers.connection = .close
            }
            return response
        }
    }

    app.on([.GET, .POST, .PUT, .PATCH, .DELETE], "redirect-to") { request -> Response in
        let url = try request.query.get(RedirectURL.self).url
        let statusCode = try? request.query.get(RedirectStatusCode.self).statusCode

        let response = Response(status: statusCode.map { HTTPResponseStatus(statusCode: $0) } ?? .found)
        response.headers.replaceOrAdd(name: .location, value: url)

        return response
    }

    app.on(.GET, "redirect", ":count") { request -> Response in
        guard let count = request.parameters["count", as: Int.self], count > 0, count < 100 else { return Response(status: .badRequest) }

        let url = if count > 1 {
            "\(request.baseURL)/redirect/\(count - 1)"
        } else {
            "\(request.baseURL)/\(request.method.rawValue.lowercased())"
        }
        let response = Response(status: .found)
        response.headers.replaceOrAdd(name: .location, value: url)

        return response
    }
}
