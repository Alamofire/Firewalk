//
//  WebSocket.swift
//
//  Copyright (c) 2020-2021 Alamofire Software Foundation (http://alamofire.org/)
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

import NIO
import NIOWebSocket
import Vapor

func createWebSocketRoutes(for app: Application) throws {
    let defaultCloseDelay: TimeAmount = .milliseconds(30)

    app.webSocket("websocket") { request, socket in
        let options = try? request.query.decode(WebSocketOptions.self)
        let closeCode = options?.closeCode ?? .normalClosure
        let closeDelay = options?.closeDelay.map(TimeAmount.milliseconds) ?? defaultCloseDelay
        let payload = try Reply(to: request)
        let payloadBuffer = try JSONEncoder().encodeAsByteBuffer(payload, allocator: app.allocator)

        let promise = request.eventLoop.makePromise(of: Void.self)
        socket.send(payloadBuffer, promise: promise)

        _ = promise.futureResult.always { _ in
            request.eventLoop.scheduleTask(in: closeDelay) {
                _ = socket.close(code: closeCode)
            }
        }
    }

    app.webSocket("websocket", "payloads", ":count") { request, socket in
        let options = try? request.query.decode(WebSocketOptions.self)
        let closeCode = options?.closeCode ?? .normalClosure
        let closeDelay = options?.closeDelay.map(TimeAmount.milliseconds) ?? defaultCloseDelay
        let count = request.parameters["count", as: Int.self] ?? 1
        do {
            let payload = try Reply(to: request)
            let payloadBuffer = try JSONEncoder().encodeAsByteBuffer(payload, allocator: app.allocator)

            let first = request.eventLoop.makeSucceededVoidFuture()
            let futures = (0..<count).map { _ -> EventLoopFuture<Void> in
                let promise = request.eventLoop.makePromise(of: Void.self)
                socket.send(payloadBuffer, promise: promise)
                return promise.futureResult
            }

            let afterAll = first.fold(futures) { _, _ in
                request.eventLoop.makeSucceededVoidFuture()
            }

            _ = afterAll.always { _ in
                request.eventLoop.scheduleTask(in: closeDelay) {
                    _ = socket.close(code: closeCode)
                }
            }
        } catch {
            request.application.logger.error("\(error.localizedDescription)")
            _ = socket.close(code: .unexpectedServerError)
        }
    }

    app.webSocket("websocket", "echo") { _, socket in
        socket.onBinary { socket, buffer in
            socket.send(buffer)
        }

        socket.onText { socket, string in
            socket.send(string)
        }
    }
}

struct WebSocketOptions: Decodable {
    let closeCode: WebSocketErrorCode?
    let closeDelay: Int64?
}

extension WebSocketErrorCode: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let rawCode = try container.decode(Int.self)
        self = Self(codeNumber: rawCode)
    }
}

extension RoutesBuilder {
    @discardableResult
    public func webSocket(_ path: PathComponent...,
                          maxFrameSize: WebSocketMaxFrameSize = .default,
                          onUpgrade: @escaping (Request, WebSocket) throws -> Void) -> Route {
        webSocket(path, maxFrameSize: maxFrameSize) { request -> EventLoopFuture<HTTPHeaders?> in
            let headers = request.headers[.secWebSocketProtocol].first.map { `protocol` -> HTTPHeaders in
                var headers = HTTPHeaders()
                headers.add(name: .secWebSocketProtocol, value: `protocol`)
                return headers
            }

            return request.eventLoop.makeSucceededFuture(headers ?? [:])
        } onUpgrade: { request, socket in
            do {
                try onUpgrade(request, socket)
            } catch {
                request.application.logger.error("\(error.localizedDescription)")
                _ = socket.close(code: .unexpectedServerError)
            }
        }
    }
}

extension WebSocket {
    func send(_ buffer: ByteBuffer, promise: EventLoopPromise<Void>? = nil) {
        send(raw: buffer.readableBytesView, opcode: .binary, promise: promise)
    }
}
