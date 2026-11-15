//
//  Inspection.swift
//
//  Copyright (c) 2022-2026 Alamofire Software Foundation (http://alamofire.org/)
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

import Synchronization
import Vapor

func createInspectionRoutes(for app: Application) throws {
    app.on(.GET, "response-headers") { request -> Response in
        let query = try request.query.decode([String: String].self)
        let encodedHeaders = try JSONEncoder().encodeAsByteBuffer(query, allocator: app.allocator)
        return Response(status: .ok, headers: HTTPHeaders(query.map(\.self)), body: .init(buffer: encodedHeaders))
    }

    let seenCaches = Mutex<Set<String>>([])

    // A version of response-headers used for Cache-Control tests, which adds an older Date to the response the first
    // time it's seen.
    app.on(.GET, "cache") { request -> Response in
        let query = try request.query.decode([String: String].self)

        guard let cache = query["Cache-Control"] else { return Response(status: .badRequest) }

        let encodedHeaders = try JSONEncoder().encodeAsByteBuffer(query, allocator: app.allocator)
        let response = Response(status: .ok, headers: HTTPHeaders(query.map(\.self)), body: .init(buffer: encodedHeaders))

        // Alternates, so every other request for the same Cache-Control value is a first request.
        let isFirstRequest = seenCaches.withLock { seenCaches in
            if seenCaches.remove(cache) != nil { return false }

            seenCaches.insert(cache)
            return true
        }
        if isFirstRequest {
            response.headers.replaceOrAdd(name: .date, value: (Date() - 5).rfc1123)
        }

        return response
    }
}
