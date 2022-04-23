//
//  Inspection.swift
//
//  Copyright (c) 2022 Alamofire Software Foundation (http://alamofire.org/)
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

func createInspectionRoutes(for app: Application) throws {
    app.on(.GET, "response-headers") { request -> Response in
        let query = try request.query.decode([String: String].self)
        let encodedHeaders = try JSONEncoder().encodeAsByteBuffer(query, allocator: app.allocator)
        return Response(status: .ok, headers: HTTPHeaders(query.map { $0 }), body: .init(buffer: encodedHeaders))
    }
    
    @Protected var seenCaches: Set<String> = []
    
    // A version of response-headers used for Cache-Control tests, which adds an older Date to the response the first
    // time it's seen.
    app.on(.GET, "cache") { request -> Response in
        let query = try request.query.decode([String: String].self)
        
        guard let cache = query["Cache-Control"] else { return Response(status: .badRequest) }
        
        let encodedHeaders = try JSONEncoder().encodeAsByteBuffer(query, allocator: app.allocator)
        let response = Response(status: .ok, headers: HTTPHeaders(query.map { $0 }), body: .init(buffer: encodedHeaders))
        
        if seenCaches.contains(cache) {
            $seenCaches.write { $0.remove(cache) }
        } else {
            $seenCaches.write { $0.insert(cache) }
            let past = Date() - 5
            response.headers.replaceOrAdd(name: .date, value: DateFormatter.rfc1123.string(from: past))
        }
        
        return response
    }
}

extension DateFormatter {
    fileprivate static let rfc1123: DateFormatter = {
        let formatter = DateFormatter()
        let enUSPosixLocale = Locale(identifier: "en_US_POSIX")
        formatter.locale = enUSPosixLocale
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter
    }()
}
