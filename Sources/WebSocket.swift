//
//  WebSocket.swift
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
import NIO
import NIOWebSocket
import Synchronization
import Vapor

func createWebSocketRoutes(for app: Application) throws {
    @Dependency(\.continuousClock) var clock

    app.webSocket("websocket") { request, socket in
        let options = try? request.query.decode(WebSocketOptions.self)
        let closeCode = options?.closeCode ?? .normalClosure
        let closeDelay = options?.closeDelay ?? 0
        let payload = try Reply(to: request)
        let payloadBuffer = try JSONEncoder().encodeAsByteBuffer(payload, allocator: app.allocator)

        socket.perform(for: request) {
            try? await socket.send(payloadBuffer)
            try await clock.sleep(for: .milliseconds(closeDelay))
            try await socket.close(code: closeCode)
        }
    }

    app.webSocket("websocket", "payloads", ":count") { request, socket in
        let options = try? request.query.decode(WebSocketOptions.self)
        let closeCode = options?.closeCode ?? .normalClosure
        let closeDelay = options?.closeDelay ?? 0
        let messageDelay = options?.messageDelay ?? 0
        let count = max(request.parameters["count", as: Int.self] ?? 1, 0)
        let payload = try Reply(to: request)
        let payloadBuffer = try JSONEncoder().encodeAsByteBuffer(payload, allocator: app.allocator)

        socket.perform(for: request) {
            do {
                for index in 0..<count {
                    try await socket.send(payloadBuffer)
                    // No delay after the final message; close delay is applied separately.
                    if index < count - 1, messageDelay > 0 {
                        try await clock.sleep(for: .milliseconds(messageDelay))
                    }
                }
            } catch {
                request.logger.debug("Sending payloads stopped: \(error)")
            }
            try await clock.sleep(for: .milliseconds(closeDelay))
            try await socket.close(code: closeCode)
        }
    }

    app.webSocket("websocket", "echo") { _, socket in
        // Synchronous sends preserve the order of echoed messages.
        socket.onBinary { socket, buffer in
            socket.send(raw: buffer.readableBytesView, opcode: .binary)
        }

        socket.onText { socket, string in
            socket.send(string)
        }
    }

    app.webSocket("websocket", "ping", ":count") { request, socket in
        let options = try? request.query.decode(WebSocketOptions.self)
        if let pongDelay = options?.pongDelay {
            socket.delayPongs(by: .milliseconds(pongDelay), using: clock)
        }

        let shouldDrop = options?.drop ?? false
        // Fewer than one ping would never close the socket.
        let remainingPings = Mutex(max(request.parameters["count", as: Int.self] ?? 1, 1))
        socket.onPing { socket, _ in
            let isLastPing = remainingPings.withLock { remainingPings in
                remainingPings -= 1
                return remainingPings == 0
            }
            if isLastPing {
                if shouldDrop {
                    socket.drop()
                } else {
                    socket.perform(for: request) { try await socket.close() }
                }
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
    /// Time to wait before sending each pong in response to a ping, in milliseconds.
    let pongDelay: Int64?
    /// Whether to drop the connection, without sending a close frame, instead of closing it normally.
    let drop: Bool?
}

extension NIOWebSocket.WebSocketErrorCode: Swift.Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let rawCode = try container.decode(Int.self)
        self = Self(codeNumber: rawCode)
    }
}

extension RoutesBuilder {
    /// Adds a WebSocket route which echoes the first requested subprotocol and supports the `openDelay` option.
    ///
    /// `onUpgrade` is intentionally synchronous: it runs on the socket's `EventLoop` before any frames are read, so
    /// handlers registered within it can't miss early frames, unlike Vapor's `async` variant, which runs in a `Task`.
    /// Use `WebSocket.perform(for:_:)` for asynchronous work.
    @discardableResult
    public func webSocket(_ path: PathComponent...,
                          maxFrameSize: WebSocketMaxFrameSize = .default,
                          onUpgrade: @escaping @Sendable (Request, WebSocket) throws -> Void) -> Route {
        @Dependency(\.continuousClock) var clock

        return webSocket(path, maxFrameSize: maxFrameSize) { request in
            // Vapor's synchronous onUpgrade requires a future-based shouldUpgrade, so bridge from async.
            request.eventLoop.makeFutureWithTask { try await webSocketShouldUpgrade(request, clock: clock) }
        } onUpgrade: { request, socket in
            do {
                try onUpgrade(request, socket)
            } catch {
                request.application.logger.error("\(error.localizedDescription)")
                socket.perform(for: request) { try await socket.close(code: .unexpectedServerError) }
            }
        }
    }
}

/// Echoes the first requested subprotocol, after waiting for the `openDelay` option, if provided.
private func webSocketShouldUpgrade(_ request: Request, clock: any Clock<Duration>) async throws -> HTTPHeaders? {
    if let openDelay = (try? request.query.decode(WebSocketOptions.self))?.openDelay {
        try await clock.sleep(for: .milliseconds(openDelay))
    }

    var headers = HTTPHeaders()
    let requestedProtocols = request.headers[.secWebSocketProtocol].flatMap { $0.split(separator: ",") }
    if let requestedProtocol = requestedProtocols.first?.trimmingCharacters(in: .whitespaces), !requestedProtocol.isEmpty {
        headers.add(name: .secWebSocketProtocol, value: requestedProtocol)
    }

    return headers
}

extension WebSocket {
    func send(_ buffer: ByteBuffer) async throws {
        try await send(raw: buffer.readableBytesView, opcode: .binary)
    }

    /// Performs `work` in a `Task`, logging any thrown error and closing the socket with `.unexpectedServerError`.
    func perform(for request: Request, _ work: @escaping @Sendable () async throws -> Void) {
        Task {
            do {
                try await work()
            } catch {
                request.logger.error("WebSocket error: \(error)")
                try? await close(code: .unexpectedServerError)
            }
        }
    }

    /// The socket's underlying `Channel`. WebSocketKit doesn't expose it, so it's found by reflection.
    private var channel: any Channel {
        guard let channel = Mirror(reflecting: self).descendant("channel") as? any Channel else {
            fatalError("Unable to find WebSocket's Channel.")
        }

        return channel
    }

    /// Closes the underlying connection without sending a close frame, simulating a dropped connection.
    func drop() {
        channel.close(promise: nil)
    }

    /// Delays every pong automatically sent by WebSocketKit in response to a ping by `delay`.
    ///
    /// WebSocketKit always responds to pings immediately, so a handler is added at the tail of the `Channel`'s
    /// pipeline, where it sees outbound frames before they're encoded.
    func delayPongs(by delay: Duration, using clock: any Clock<Duration>) {
        @Sendable
        func addHandler() {
            do {
                try channel.pipeline.syncOperations.addHandler(PongDelayHandler(delay: delay, clock: clock))
            } catch {
                fatalError("Unable to add PongDelayHandler: \(error)")
            }
        }

        if channel.eventLoop.inEventLoop {
            addHandler()
        } else {
            channel.eventLoop.execute(addHandler)
        }
    }
}

/// Outbound handler which delays pong frames by `delay`, passing all other frames through immediately.
///
/// Pongs are written in the order they were sent, even if their delays complete out of order.
private final class PongDelayHandler: ChannelOutboundHandler, RemovableChannelHandler {
    typealias OutboundIn = WebSocketFrame
    typealias OutboundOut = WebSocketFrame

    private let delay: Duration
    private let clock: any Clock<Duration>
    private var previousPong: EventLoopFuture<Void>?

    init(delay: Duration, clock: any Clock<Duration>) {
        self.delay = delay
        self.clock = clock
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        guard unwrapOutboundIn(data).opcode == .pong else {
            context.write(data, promise: promise)
            return
        }

        let delay = delay
        let clock = clock
        let delayed = context.eventLoop.makeFutureWithTask { try await clock.sleep(for: delay) }
        let previous = previousPong ?? context.eventLoop.makeSucceededVoidFuture()
        let boundContext = NIOLoopBound(context, eventLoop: context.eventLoop)
        let boundData = NIOLoopBound(data, eventLoop: context.eventLoop)
        let written = previous.and(delayed).flatMap { _ in
            boundContext.value.writeAndFlush(boundData.value)
        }
        written.cascade(to: promise)
        previousPong = written.recover { _ in }
    }
}
