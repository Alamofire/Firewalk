//
//  BasicAuth.swift
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

func createBasicAuthRoutes(for app: Application) throws {
    let basicAuth = app.grouped(BasicPathAuthenticator())
    basicAuth.on([.GET, .POST, .PUT, .PATCH, .DELETE], "basic-auth", ":user", ":passwd") { request -> EventLoopFuture<Response> in
        guard request.isAuthenticated else {
            var headers = HTTPHeaders()
            headers.add(name: .wwwAuthenticate, value: "Basic")
            return request.eventLoop.makeSucceededFuture(Response(status: .unauthorized, headers: headers))
        }

        return try Reply(to: request).encodeResponse(for: request)
    }

    basicAuth.on([.GET, .POST, .PUT, .PATCH, .DELETE], "hidden-basic-auth", ":user", ":passwd") { request -> EventLoopFuture<Response> in
        guard request.isAuthenticated else {
            return request.eventLoop.makeSucceededFuture(Response(status: .unauthorized))
        }

        return try Reply(to: request).encodeResponse(for: request)
    }
}

struct BasicPathAuthenticator: BasicAuthenticator {
    enum Error: Swift.Error { case invalidRequest }

    func authenticate(basic: BasicAuthorization, for request: Request) -> EventLoopFuture<Void> {
        guard let username = request.parameters["user", as: String.self],
            let password = request.parameters["passwd", as: String.self] else {
            return request.eventLoop.makeFailedFuture(Error.invalidRequest)
        }

        if basic.username == username, basic.password == password {
            request.auth.login(request)
        }

        return request.eventLoop.makeSucceededFuture(())
    }
}
