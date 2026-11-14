//
//  Firewalk.swift
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

@main
enum Firewalk {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        let app = try await Application.make(env)
        // Separate instance, as an `Application`'s HTTP server configuration is shared by all of its servers.
        let tlsApp = try await Application.make(Environment(name: env.name, arguments: ["firewalk"]))

        do {
            try configure(app)
            try configureTLS(tlsApp)
            try tlsApp.server.start()
            try await app.execute()
        } catch {
            app.logger.report(error: error)
            await tlsApp.server.shutdown()
            try? await tlsApp.asyncShutdown()
            try? await app.asyncShutdown()
            throw error
        }

        await tlsApp.server.shutdown()
        try await tlsApp.asyncShutdown()
        try await app.asyncShutdown()
    }

    /// Configures `app` with all routes, served over TLS on port `8443` or `FIREWALK_TLS_PORT`. Both HTTP/1.1 and
    /// HTTP/2 are offered using ALPN, so clients which support HTTP/2, like `URLSession`, will use it. HTTP/2 is only
    /// available over TLS, as neither Vapor nor `URLSession` support HTTP/2 over cleartext (h2c).
    static func configureTLS(_ app: Application) throws {
        try configure(app)
        app.http.server.configuration.port = Environment.get("FIREWALK_TLS_PORT").flatMap(Int.init) ?? 8443
        app.http.server.configuration.supportVersions = [.one, .two]
        app.http.server.configuration.tlsConfiguration = try TLSIdentity.serverConfiguration()
    }
}
