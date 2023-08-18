//
//  Data.swift
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

import AsyncKit
import Vapor

func createDataRoutes(for app: Application) throws {
    app.on(.GET, "bytes", ":count") { request -> Response in
        guard let count = request.parameters["count", as: Int.self], count <= 100_000 else {
            return Response(status: .badRequest)
        }

        var buffer = request.application.allocator.buffer(capacity: count)
        let big = count / 8
        let remainder = count % 8

        for _ in 0..<big {
            buffer.writeInteger(UInt64.random())
        }

        for _ in 0..<remainder {
            buffer.writeInteger(UInt8.random())
        }

        return Response(body: .init(buffer: buffer))
    }

    app.on(.GET, "stream", ":count") { request -> Response in
        guard let count = request.parameters["count", as: Int.self], count > 0, count <= 100 else {
            return Response(status: .badRequest)
        }

        let encoder = JSONEncoder()
        let reply = try Reply(to: request)
        var encodedReply = try encoder.encodeAsByteBuffer(reply, allocator: app.allocator)
        var buffer = app.allocator.buffer(capacity: (encodedReply.readableBytes * count) + (count - 1))
        for _ in 1..<count {
            buffer.writeBuffer(&encodedReply)
            buffer.writeString("\n")
        }
        buffer.writeBuffer(&encodedReply)

        return Response(body: .init(buffer: buffer))
    }

    app.on(.GET, "manyBytes", ":count") { request -> Response in
        guard let count = request.parameters["count", as: Int.self], count <= 10_000_000 else {
            return Response(status: .badRequest)
        }

        var buffer = request.application.allocator.buffer(capacity: count)
        buffer.writeRepeatingByte(UInt8.random(), count: count)

        return Response(body: .init(buffer: buffer))
    }

    app.on(.GET, "chunked", ":count") { request -> Response in
        guard let count = request.parameters["count", as: Int.self], count > 0, count <= 100 else {
            return Response(status: .badRequest)
        }

        let response = Response(body: .init(stream: { writer in
            var bytesToSend = count
            request.eventLoop.scheduleRepeatedTask(initialDelay: .seconds(0), delay: .milliseconds(20)) { task in
                guard bytesToSend > 0 else { task.cancel(); _ = writer.write(.end); return }

                _ = writer.write(.buffer(.init(integer: UInt8(bytesToSend))))
                bytesToSend -= 1
            }
        }))

        response.headers.replaceOrAdd(name: .contentType, value: "application/octet-stream")
        return response
    }

    app.on(.GET, "payloads", ":count") { request -> Response in
        guard let count = request.parameters["count", as: Int.self], count > 0, count <= 100 else {
            return Response(status: .badRequest)
        }

        let encoder = JSONEncoder()
        let reply = try Reply(to: request)
        let encodedReply = try encoder.encodeAsByteBuffer(reply, allocator: app.allocator)
        let response = Response(body: .init(stream: { writer in
            var payloadsToSend = count
            request.eventLoop.scheduleRepeatedTask(initialDelay: .seconds(0), delay: .milliseconds(20)) { task in
                guard payloadsToSend > 0 else { task.cancel(); _ = writer.write(.end); return }

                _ = writer.write(.buffer(encodedReply))
                payloadsToSend -= 1
            }
        }))

        response.headers.replaceOrAdd(name: .contentType, value: "application/octet-stream")
        return response
    }

    app.on(.GET, "infinite") { request -> Response in
        Response(body: .init(stream: { writer in
            let buffer = request.application.allocator.buffer(repeating: 1, count: 100_000_000)

            func writeBuffer() {
                writer.write(.buffer(buffer)).whenComplete { result in
                    switch result {
                    case .success:
                        request.eventLoop.execute { writeBuffer() }
                    case let .failure(error):
                        request.application.logger.error("Infinite stream finished with error: \(error)")
                        _ = writer.write(.end)
                    }
                }
            }

            writeBuffer()
        }))
    }
}
