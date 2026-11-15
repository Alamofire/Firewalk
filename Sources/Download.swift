//
//  Download.swift
//
//  Copyright (c) 2021-2026 Alamofire Software Foundation (http://alamofire.org/)
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

func createDownloadRoutes(for app: Application) throws {
    @Dependency(\.continuousClock) var clock

    app.on(.GET, "download", ":count") { request -> Response in
        guard let totalCount = request.parameters["count", as: Int.self],
              (0...10_000_000).contains(totalCount),
              totalCount.isMultiple(of: 10) else {
            return .init(status: .badRequest)
        }

        let shouldProduceError = (try? request.query.get(Bool.self, at: "shouldProduceError")) ?? false
        let includeETag = (try? request.query.get(Bool.self, at: "etag")) ?? false
        let omitLastModified = (try? request.query.get(Bool.self, at: "noLastModified")) ?? false
        let omitAcceptRanges = (try? request.query.get(Bool.self, at: "noAcceptRanges")) ?? false

        request.logger.debug("download \(totalCount) Range=\(request.headers.first(name: .range) ?? "nil") If-Range=\(request.headers.first(name: .ifRange) ?? "nil") If-Match=\(request.headers.first(name: .ifMatch) ?? "nil")")

        let response: Response
        switch ByteRange(request.headers.range, length: totalCount) {
        case .unsatisfiable:
            let rejected = Response(status: .rangeNotSatisfiable)
            rejected.headers.replaceOrAdd(name: .contentRange, value: "bytes */\(totalCount)")
            return rejected
        case let .satisfiable(bounds):
            let buffer = request.application.allocator.buffer(repeating: UInt8.random(), count: bounds.count)
            response = Response(status: .partialContent, body: .init(buffer: buffer))
            response.headers.contentRange = .init(unit: .bytes,
                                                  range: .withinWithLimit(start: bounds.lowerBound,
                                                                          end: bounds.upperBound,
                                                                          limit: totalCount))
        case .whole:
            response = Response(body: .init(managedAsyncStream: { writer in
                // The body repeats one byte, so one segment is written ten times, as writes don't copy it.
                let segment = request.application.allocator.buffer(repeating: UInt8.random(), count: totalCount / 10)
                var bytesToSend = totalCount
                while bytesToSend > 0 {
                    if shouldProduceError, bytesToSend < (totalCount / 2) {
                        throw URLError(.networkConnectionLost)
                    }

                    try await writer.writeBuffer(segment)
                    bytesToSend -= segment.readableBytes
                    try await clock.sleep(for: .milliseconds(1))
                }
            }))
            if !omitAcceptRanges { response.headers.add(name: .acceptRanges, value: "bytes") }
            response.headers.replaceOrAdd(name: .contentLength, value: "\(totalCount)")
            response.headers.remove(name: .transferEncoding)
        }

        response.headers.replaceOrAdd(name: .contentType, value: "application/octet-stream")
        if !omitLastModified { response.headers.add(name: .lastModified, value: lastModified) }
        if includeETag { response.headers.add(name: .eTag, value: "\"v1\"") }

        return response
    }
}

/// Last-Modified for every download, so validators match across requests.
private let lastModified = Date(timeIntervalSinceReferenceDate: 0).rfc1123

/// What a `Range` header selects from a body of `length` bytes, per RFC 9110.
enum ByteRange: Equatable {
    /// The whole body, as when there's no `Range`, it's invalid, or it asks for more than one range, which would need a
    /// `multipart/byteranges` response.
    case whole
    /// No bytes, for a `416`.
    case unsatisfiable
    /// The first and last offsets of the bytes selected.
    case satisfiable(ClosedRange<Int>)

    init(_ range: HTTPHeaders.Range?, length: Int) {
        guard let range, range.unit == .bytes, range.ranges.count == 1, let value = range.ranges.first else {
            self = .whole
            return
        }

        switch value {
        case let .start(start):
            self = start < length ? .satisfiable(start...(length - 1)) : .unsatisfiable
        case let .tail(count):
            self = count > 0 && length > 0 ? .satisfiable(max(length - count, 0)...(length - 1)) : .unsatisfiable
        case let .within(start, end):
            if start > end {
                self = .whole
            } else {
                self = start < length ? .satisfiable(start...min(end, length - 1)) : .unsatisfiable
            }
        }
    }
}
