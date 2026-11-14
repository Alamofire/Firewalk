//
//  DelayTests.swift
//
//  Copyright (c) 2026 Alamofire Software Foundation (http://alamofire.org/)
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

@testable import firewalk
import Dependencies
import DependenciesTestSupport
import Testing
import VaporTesting

@Suite(.timeLimit(.minutes(1)))
struct DelayTests {
    @Test(.dependency(\.continuousClock, TestClock()))
    func `delay responds only after the interval`() async throws {
        // Given
        let clock = try testClock()
        try await withApp(configure: configure) { app in
            let responded = LockIsolated(false)

            // When
            let request = Task {
                try await app.testing().test(.GET, "delay/2") { response in
                    responded.setValue(true)
                    #expect(response.status == .ok)
                }
            }

            // Then
            await clock.expectSleep(for: .seconds(2)) { !responded.value }
            try await request.value
            #expect(responded.value)
        }
    }

    @Test(.dependency(\.continuousClock, TestClock()))
    func `delay over ten seconds responds immediately`() async throws {
        // Given, When
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "delay/11") { response in
                // Then
                #expect(response.status == .ok)
            }
        }
    }

    @Test(.dependency(\.continuousClock, TestClock()))
    func `chunked waits after each chunk`() async throws {
        // Given
        let clock = try testClock()
        try await withApp(configure: configure) { app in
            let responded = LockIsolated(false)

            // When
            let request = Task {
                try await app.testing().test(.GET, "chunked/3/10") { response in
                    responded.setValue(true)
                    #expect(response.status == .ok)
                    #expect(Array(response.body.readableBytesView) == [3, 2, 1])
                }
            }

            // Then
            for _ in 0..<3 {
                await clock.expectSleep(for: .milliseconds(10)) { !responded.value }
            }
            try await request.value
            #expect(responded.value)
        }
    }

    @Test(.dependency(\.continuousClock, TestClock()))
    func `payloads waits after each payload`() async throws {
        // Given
        let clock = try testClock()
        try await withApp(configure: configure) { app in
            let responded = LockIsolated(false)

            // When
            let request = Task {
                try await app.testing().test(.GET, "payloads/2/5") { response in
                    responded.setValue(true)
                    #expect(response.status == .ok)
                    #expect(response.body.string.components(separatedBy: "\"url\"").count == 3)
                }
            }

            // Then
            for _ in 0..<2 {
                await clock.expectSleep(for: .milliseconds(5)) { !responded.value }
            }
            try await request.value
            #expect(responded.value)
        }
    }

    @Test(.dependency(\.continuousClock, TestClock()))
    func `download waits after each segment`() async throws {
        // Given
        let clock = try testClock()
        try await withApp(configure: configure) { app in
            let responded = LockIsolated(false)

            // When
            let request = Task {
                try await app.testing().test(.GET, "download/100") { response in
                    responded.setValue(true)
                    #expect(response.status == .ok)
                    #expect(response.body.readableBytes == 100)
                    #expect(response.headers.first(name: .contentLength) == "100")
                }
            }

            // Then
            for _ in 0..<10 {
                await clock.expectSleep(for: .milliseconds(1)) { !responded.value }
            }
            try await request.value
            #expect(responded.value)
        }
    }

    @Test(.dependency(\.continuousClock, TestClock()))
    func `websocket payloads wait between messages and before closing`() async throws {
        // Given
        let clock = try testClock()
        try await withRunningApp { app, port in
            // When
            let client = try await WebSocketClientSpy.connect(to: "ws://127.0.0.1:\(port)/websocket/payloads/3?messageDelay=5&closeDelay=7",
                                                              on: app)
            var messages = client.messages.makeAsyncIterator()

            // Then
            for (received, delay) in zip(1...3, [5, 5, 7]) {
                await messages.next()
                await clock.expectSleep(for: .milliseconds(delay)) {
                    client.messageCount.value == received && !client.socket.isClosed
                }
            }
            try await client.socket.onClose.get()
            #expect(client.messageCount.value == 3)
            #expect(client.socket.closeCode == .normalClosure)
        }
    }

    @Test(.dependency(\.continuousClock, TestClock()))
    func `websocket closes only after the close delay`() async throws {
        // Given
        let clock = try testClock()
        try await withRunningApp { app, port in
            // When
            let client = try await WebSocketClientSpy.connect(to: "ws://127.0.0.1:\(port)/websocket?closeDelay=30&closeCode=1001",
                                                              on: app)

            // Then
            await clock.expectSleep(for: .milliseconds(30)) { !client.socket.isClosed }
            try await client.socket.onClose.get()
            #expect(client.messageCount.value == 1)
            #expect(client.socket.closeCode == .goingAway)
        }
    }

    @Test(.dependency(\.continuousClock, TestClock()))
    func `websocket upgrades only after the open delay`() async throws {
        // Given
        let clock = try testClock()
        try await withRunningApp { app, port in
            let connected = LockIsolated(false)

            // When
            let connection = Task {
                let client = try await WebSocketClientSpy.connect(to: "ws://127.0.0.1:\(port)/websocket/echo?openDelay=50", on: app)
                connected.setValue(true)
                return client
            }

            // Then
            await clock.expectSleep(for: .milliseconds(50)) { !connected.value }
            let client = try await connection.value
            #expect(connected.value)
            try await client.socket.close()
        }
    }

    @Test(.dependency(\.continuousClock, TestClock()))
    func `websocket pongs are sent only after the pong delay`() async throws {
        // Given
        let clock = try testClock()
        try await withRunningApp { app, port in
            let client = try await WebSocketClientSpy.connect(to: "ws://127.0.0.1:\(port)/websocket/ping/2?pongDelay=20", on: app)
            var pongs = client.pongs.makeAsyncIterator()

            // When
            try await client.socket.sendPing()

            // Then
            await clock.expectSleep(for: .milliseconds(20)) { client.pongCount.value == 0 }
            await pongs.next()
            #expect(client.pongCount.value == 1)
            try await client.socket.close()
        }
    }

    private func testClock() throws -> TestClock<Duration> {
        @Dependency(\.continuousClock) var clock
        return try #require(clock as? TestClock<Duration>)
    }

    /// Runs the app on an ephemeral port, since WebSockets can't be tested in memory.
    private func withRunningApp(_ test: (Application, Int) async throws -> Void) async throws {
        try await withApp(configure: configure) { app in
            try await app.server.start(address: .hostname("127.0.0.1", port: 0))
            do {
                let port = try #require(app.http.server.shared.localAddress?.port)
                try await test(app, port)
            } catch {
                await app.server.shutdown()
                throw error
            }
            await app.server.shutdown()
        }
    }
}

extension TestClock<Duration> {
    /// Waits for the server to start sleeping, then advances the clock through `delay`, expecting `isPending` to hold
    /// until the full delay has elapsed.
    ///
    /// If the server sleeps for less than `delay`, or finishes without sleeping, `isPending` fails. If it sleeps for
    /// longer, it never wakes and the test times out.
    func expectSleep(for delay: Duration,
                     whilePending isPending: () -> Bool,
                     sourceLocation: SourceLocation = #_sourceLocation) async {
        // The server sleeps on its own event loops, so wait for it. `checkSuspension()` throws only while a sleep is
        // pending.
        while await (try? checkSuspension()) != nil, isPending() {}
        guard isPending() else {
            Issue.record("Finished without sleeping for \(delay).", sourceLocation: sourceLocation)
            return
        }

        await advance(by: delay - .milliseconds(1))
        #expect(isPending(), "Finished before \(delay) elapsed.", sourceLocation: sourceLocation)
        await advance(by: .milliseconds(1))
    }
}

/// Connects a WebSocket client which records the messages and pongs it receives.
private struct WebSocketClientSpy: Sendable {
    /// Single event loop on which all client connections are set up.
    ///
    /// Setting up a client channel calls `NIOWebSocketClientUpgrader.randomRequestKey()`, whose `inout` access to an
    /// empty `SystemRandomNumberGenerator` is reported by ThreadSanitizer as a Swift access race when two connections
    /// are set up concurrently on different threads. That's a false positive, as no state is shared, but it fails
    /// `swift test --sanitize=thread`. Setting up every client on the same event loop orders those accesses.
    private static let eventLoop = MultiThreadedEventLoopGroup.singleton.next()

    let socket: WebSocket
    let messageCount: LockIsolated<Int>
    let messages: AsyncStream<ByteBuffer>
    let pongCount: LockIsolated<Int>
    let pongs: AsyncStream<Void>

    static func connect(to url: String, on app: Application) async throws -> Self {
        let messageCount = LockIsolated(0)
        let (messages, messageContinuation) = AsyncStream<ByteBuffer>.makeStream()
        let pongCount = LockIsolated(0)
        let (pongs, pongContinuation) = AsyncStream<Void>.makeStream()
        let (sockets, socketContinuation) = AsyncStream<WebSocket>.makeStream()

        // Vapor's async connect drops the URL's query, so use WebSocketKit's future-based connect.
        // Connecting completes before the upgrade, so wait for the upgraded socket.
        let connection: EventLoopFuture<Void> = WebSocket.connect(to: url, on: eventLoop) { connected in
            socketContinuation.yield(connected)
            connected.onBinary { _, buffer in
                messageCount.withValue { $0 += 1 }
                messageContinuation.yield(buffer)
            }
            connected.onPong { _, _ in
                pongCount.withValue { $0 += 1 }
                pongContinuation.yield()
            }
        }

        try await connection.get()
        var upgradedSockets = sockets.makeAsyncIterator()
        let socket = try #require(await upgradedSockets.next())

        return Self(socket: socket, messageCount: messageCount, messages: messages, pongCount: pongCount, pongs: pongs)
    }
}
