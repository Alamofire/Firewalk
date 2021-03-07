//
//  WebSocket.swift
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

import NIOWebSocket
import Vapor

func createWebSocketRoutes(for app: Application) throws {
    app.webSocket("websocket") { request, socket in
        let closeCode = (try? request.query.decode(WebSocketOptions.self).closeCode) ?? .normalClosure
        let payload = try Reply(to: request)
        let payloadBuffer = try JSONEncoder().encodeAsByteBuffer(payload, allocator: app.allocator)
        socket.send(payloadBuffer)
        _ = socket.close(code: closeCode)
    }

    app.webSocket("websocket", "payloads", ":count") { request, socket in
        let count = request.parameters["count", as: Int.self] ?? 1
        do {
            let payload = try Reply(to: request)
            let payloadBuffer = try JSONEncoder().encodeAsByteBuffer(payload, allocator: app.allocator)

            for _ in 0..<count {
                socket.send(payloadBuffer)
            }

            _ = socket.close(code: .normalClosure)
        } catch {
            request.application.logger.error("\(error.localizedDescription)")
            _ = socket.close(code: .unexpectedServerError)
        }
    }

    app.webSocket("websocket", "echo") { request, socket in
        socket.onBinary { socket, buffer in
            request.application.logger.info("Sending echo.")
            socket.send(buffer)
        }
    }
}

struct WebSocketOptions: Decodable {
    let closeCode: WebSocketErrorCode
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
        webSocket(path, maxFrameSize: maxFrameSize) { request, socket in
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
        send(raw: buffer.readableBytesView, opcode: .binary)
    }
}
