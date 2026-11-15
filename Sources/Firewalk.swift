//
//  Firewalk.swift
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

import ArgumentParser
import Vapor

// Enforce minimum Swift version for all platforms and build systems.
#if compiler(<6.4)
#error("Firewalk doesn't support Swift compiler versions below 6.4.")
#endif

@main
struct Firewalk: AsyncParsableCommand {
    /// Current Firewalk version, served from `/version` so clients can check that Firewalk supports the routes and
    /// behaviors they use. Update it for every release.
    static let version = "0.16.0"

    static let configuration = CommandConfiguration(
        commandName: "firewalk",
        abstract: "An HTTP test server implementing a subset of httpbin.org, with additional features.",
        discussion: """
        Every route is served over HTTP on --port, over HTTP/1.1 and HTTP/2 with TLS and a self-signed certificate on \
        --tls-port, and the same with an expired certificate on --expired-tls-port. Each option can also be set by the \
        environment variable named in its help, which an option given on the command line overrides.
        """,
        version: version
    )

    @ArgumentParser.Option(help: "The address to listen on. (FIREWALK_HOSTNAME, default: \(Settings.default.hostname))")
    var hostname: String?

    @ArgumentParser.Option(help: "The HTTP port. (FIREWALK_PORT, default: \(Settings.default.port))")
    var port: Int?

    @ArgumentParser.Option(name: .customLong("tls-port"),
                           help: "The TLS port, with a self-signed certificate. (FIREWALK_TLS_PORT, default: \(Settings.default.tlsPort))")
    var tlsPort: Int?

    @ArgumentParser.Option(name: .customLong("expired-tls-port"),
                           help: "The TLS port with an expired certificate. (FIREWALK_EXPIRED_TLS_PORT, default: \(Settings.default.expiredTLSPort))")
    var expiredTLSPort: Int?

    @ArgumentParser.Option(help: """
    The largest request body accepted, in bytes or with a kb, mb, or gb suffix. (FIREWALK_MAX_BODY_SIZE, default: \
    \(Settings.default.maxBodySize))
    """)
    var maxBodySize: ByteSize?

    @ArgumentParser.Option(help: """
    How many connections each port queues before accepting them. The OS may lower it, with kern.ipc.somaxconn on \
    macOS. (FIREWALK_BACKLOG, default: \(Settings.default.backlog))
    """)
    var backlog: Int?

    @ArgumentParser.Option(help: """
    The most connections accepted at once by each event loop. (FIREWALK_CONNECTIONS_PER_TICK, default: \
    \(Settings.default.connectionsPerTick))
    """)
    var connectionsPerTick: UInt?

    @ArgumentParser.Option(help: "The minimum level logged. (FIREWALK_LOG_LEVEL, default: \(Settings.default.logLevel))")
    var logLevel: Logger.Level?

    func validate() throws {
        _ = try settings(environment: ProcessInfo.processInfo.environment)
    }

    func run() async throws {
        let settings = try settings(environment: ProcessInfo.processInfo.environment)
        LoggingSystem.bootstrap(console: Terminal(), level: settings.logLevel)
        // Vapor's own command line handling only needs to run its default `serve` command.
        let env = try Environment.detect(arguments: ["firewalk"])
        let app = try await Application.make(env)
        // Separate instances, as an `Application`'s HTTP server configuration is shared by all of its servers.
        let tlsApps = try await [Application.make(env), Application.make(env)]

        do {
            try configure(app, settings: settings)
            app.http.server.configuration.hostname = settings.hostname
            app.http.server.configuration.port = settings.port
            try Self.configureTLS(tlsApps[0], settings: settings)
            try Self.configureExpiredTLS(tlsApps[1], settings: settings)
            for tlsApp in tlsApps {
                try tlsApp.server.start()
            }
            try await app.execute()
        } catch {
            app.logger.report(error: error)
            await Self.shutdown(tlsApps)
            try? await app.asyncShutdown()
            throw error
        }

        await Self.shutdown(tlsApps)
        try await app.asyncShutdown()
    }

    private static func shutdown(_ apps: [Application]) async {
        for app in apps {
            await app.server.shutdown()
            try? await app.asyncShutdown()
        }
    }

    /// Configures `app` with all routes, served over TLS on `settings.tlsPort`. Both HTTP/1.1 and HTTP/2 are offered
    /// using ALPN, so clients which support HTTP/2, like `URLSession`, will use it. HTTP/2 is only available over TLS, as
    /// neither Vapor nor `URLSession` support HTTP/2 over cleartext (h2c).
    static func configureTLS(_ app: Application, settings: Settings) throws {
        try configure(app, settings: settings)
        app.http.server.configuration.hostname = settings.hostname
        app.http.server.configuration.port = settings.tlsPort
        app.http.server.configuration.supportVersions = [.one, .two]
        app.http.server.configuration.tlsConfiguration = try TLSIdentity.serverConfiguration()
    }

    /// Configures `app` with all routes, served over TLS on `settings.expiredTLSPort` using a certificate that expired in
    /// 2020, issued through two intermediate CAs by a root CA no system trusts. It stands in for expired.badssl.com, so
    /// clients can test server trust evaluation locally. The certificates are in `ExpiredCertificates`.
    static func configureExpiredTLS(_ app: Application, settings: Settings) throws {
        try configure(app, settings: settings)
        app.http.server.configuration.hostname = settings.hostname
        app.http.server.configuration.port = settings.expiredTLSPort
        app.http.server.configuration.supportVersions = [.one, .two]
        app.http.server.configuration.tlsConfiguration = try ExpiredCertificates.serverConfiguration()
    }
}

extension Firewalk {
    /// The settings from these options, falling back to `environment`, then to `Settings.default`.
    func settings(environment: [String: String]) throws -> Settings {
        func resolve<Value: ExpressibleByArgument>(_ option: Value?, _ variable: String, _ fallback: Value) throws -> Value {
            if let option { return option }
            guard let string = environment[variable], !string.isEmpty else { return fallback }
            guard let value = Value(argument: string) else {
                throw ValidationError("\(variable) is '\(string)', which isn't valid.")
            }

            return value
        }

        let defaults = Settings.default
        let settings = try Settings(hostname: resolve(hostname, "FIREWALK_HOSTNAME", defaults.hostname),
                                    port: resolve(port, "FIREWALK_PORT", defaults.port),
                                    tlsPort: resolve(tlsPort, "FIREWALK_TLS_PORT", defaults.tlsPort),
                                    expiredTLSPort: resolve(expiredTLSPort, "FIREWALK_EXPIRED_TLS_PORT", defaults.expiredTLSPort),
                                    maxBodySize: resolve(maxBodySize, "FIREWALK_MAX_BODY_SIZE", ByteSize(defaults.maxBodySize)).bytes,
                                    backlog: resolve(backlog, "FIREWALK_BACKLOG", defaults.backlog),
                                    connectionsPerTick: resolve(connectionsPerTick, "FIREWALK_CONNECTIONS_PER_TICK", defaults.connectionsPerTick),
                                    logLevel: resolve(logLevel, "FIREWALK_LOG_LEVEL", defaults.logLevel))
        try settings.validate()

        return settings
    }
}
