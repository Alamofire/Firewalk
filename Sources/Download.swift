//
//  Download.swift
//
//  Copyright (c) 2021 Alamofire Software Foundation (http://alamofire.org/)
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

func createDownloadRoutes(for app: Application) throws {
    app.on(.GET, "download", ":count") { request -> Response in
        guard let totalCount = request.parameters["count", as: Int.self],
              totalCount <= 10_000_000,
              totalCount.isMultiple(of: 10) else {
            return .init(status: .badRequest)
        }

        let shouldProduceError = (try? request.query.get(Bool.self, at: "shouldProduceError")) ?? false

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy hh:mm:ss zzz"
        let lastModified = formatter.string(from: Date(timeIntervalSinceReferenceDate: 0))

        let response: Response

        if let range = request.headers.range {
            let byteCount = range.ranges.reduce(0) { result, value in
                switch value {
                case let .start(value):
                    return result + (totalCount - value)
                case let .tail(value):
                    return result + value
                case let .within(start, end):
                    return result + (end - start)
                }
            }

            let buffer = request.application.allocator.buffer(repeating: UInt8.random(), count: byteCount)
            response = Response(status: .partialContent, body: .init(buffer: buffer))
            response.headers.contentRange = .init(unit: .bytes, range: .within(start: totalCount - byteCount, end: totalCount))
        } else {
            response = Response(body: .init(stream: { writer in
                var buffer = request.application.allocator.buffer(repeating: UInt8.random(), count: totalCount)
                var bytesToSend = totalCount
                let segment = (totalCount / 10)
                request.eventLoop.scheduleRepeatedTask(initialDelay: .seconds(0), delay: .milliseconds(1)) { task in
                    guard bytesToSend > 0 else { task.cancel(); _ = writer.write(.end); return }

                    if shouldProduceError, bytesToSend < (totalCount / 2) {
                        task.cancel()
                        _ = writer.write(.error(URLError(.networkConnectionLost)))
                        return
                    }

                    guard let bytes = buffer.readSlice(length: segment) else {
                        request.logger.info("Failed to read \(segment) bytes from buffer with \(buffer.readableBytes) bytes, ending write.")
                        task.cancel()
                        return
                    }

                    _ = writer.write(.buffer(bytes))
                    bytesToSend -= segment
                }
            }))
            response.headers.add(name: .acceptRanges, value: "bytes")
            response.headers.replaceOrAdd(name: .contentLength, value: "\(totalCount)")
            response.headers.remove(name: .transferEncoding)
        }

        response.headers.replaceOrAdd(name: .contentType, value: "application/octet-stream")
        response.headers.add(name: .lastModified, value: lastModified)

        return response
    }
}
