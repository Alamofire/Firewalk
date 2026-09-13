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

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#else
#error("Unsupported platform needs a sleep() equivalent.")
#endif
import NIO
import NIOWebSocket
import Vapor

func createWebSocketRoutes(for app: Application) throws {
    let defaultCloseDelay: TimeAmount = .milliseconds(0)

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
        let messageDelay = options?.messageDelay.map(TimeAmount.milliseconds) ?? .zero
        let count = request.parameters["count", as: Int.self] ?? 1
        do {
            let payload = try Reply(to: request)
            let payloadBuffer = try JSONEncoder().encodeAsByteBuffer(payload, allocator: app.allocator)

            // Send messages sequentially, inserting messageDelay between each one.
            @Sendable
            func sendNext(_ remaining: Int) -> EventLoopFuture<Void> {
                guard remaining > 0 else {
                    return request.eventLoop.makeSucceededVoidFuture()
                }
                let promise = request.eventLoop.makePromise(of: Void.self)
                socket.send(payloadBuffer, promise: promise)
                return promise.futureResult.flatMap {
                    // No delay after the final message; close delay is applied separately.
                    guard remaining > 1, messageDelay != .zero else {
                        return sendNext(remaining - 1)
                    }
                    return request.eventLoop.scheduleTask(in: messageDelay) {}.futureResult
                        .flatMap { sendNext(remaining - 1) }
                }
            }

            _ = sendNext(count).always { _ in
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

    app.webSocket("websocket", "ping", ":count") { request, socket in
        let remainingPings = Protected(request.parameters["count", as: Int.self] ?? 1)
        socket.onPing { _, _ in
            remainingPings.write { $0 -= 1 }
            if remainingPings.read({ $0 == 0 }) {
                _ = socket.close()
            }
        }
    }
}

struct WebSocketOptions: Decodable {
    /// Code to return when closing.
    let closeCode: WebSocketErrorCode?
    /// Time to wait before closing the connection, in milliseconds.
    let closeDelay: Int64?
    /// Time to wait between sequential messages.
    let messageDelay: Int64?
    /// Time to wait before accepting the connection.
    let openDelay: Int64?
}

extension NIOWebSocket.WebSocketErrorCode: Swift.Decodable {
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
                          onUpgrade: @escaping @Sendable (Request, WebSocket) throws -> Void) -> Route {
        webSocket(path, maxFrameSize: maxFrameSize) { request -> EventLoopFuture<HTTPHeaders?> in
            let headers = request.headers[.secWebSocketProtocol].first?.components(separatedBy: ", ").first.map { `protocol` -> HTTPHeaders in
                var headers = HTTPHeaders()
                headers.add(name: .secWebSocketProtocol, value: String(`protocol`))
                return headers
            }

            // If openDelay is requested, schedule the completion of the upgrade future on the event loop after the given delay.
            return if let options = try? request.query.decode(WebSocketOptions.self), let openDelay = options.openDelay {
                request.eventLoop.scheduleTask(in: .milliseconds(openDelay)) {
                    headers ?? [:]
                }.futureResult
            } else {
                request.eventLoop.makeSucceededFuture(headers ?? [:])
            }
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
