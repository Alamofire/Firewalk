//
//  Replies.swift
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

struct Reply: Content {
    let url: String
    let origin: String
    let headers: HTTPHeaders
    let data: String?
    let form: [String: String]?
    let args: [String: String]
}

extension Reply {
    init(to request: Request) throws {
        url = "\(request.application.http.server.configuration.address)\(request.url.string)"
        origin = request.remoteAddress?.description ?? "No remote address."
        headers = request.headers
        let bodyString = request.body.string
        data = (bodyString?.isEmpty == true) ? nil : bodyString
        form = try? request.content.get([String: String].self, at: [])
        args = try request.query.get([String: String].self, at: [])
    }
}

struct IPReply: Content {
    let origin: String
}

struct RedirectURL: Decodable {
    let url: String
}
