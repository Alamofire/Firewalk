//
//  configure.swift
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

import Vapor

public func configure(_ app: Application) throws {
    #if DEBUG
    app.logger.logLevel = .info
    #else
    app.logger.logLevel = .critical
    #endif

    // Large enough for the biggest upload tests, so oversized bodies aren't rejected with a 413 mid-upload.
    app.routes.defaultMaxBodySize = 100_000_000
    app.http.server.configuration.requestDecompression = .enabled
    // Test suites running in parallel open bursts of connections; a deeper listen queue and accepting more connections
    // per event loop tick keep those bursts from being refused. The OS may cap the backlog (kern.ipc.somaxconn on macOS).
    app.http.server.configuration.backlog = 4096
    app.http.server.configuration.connectionsPerServerTick = 1024

    try createBasicAuthRoutes(for: app)
    try createCompressionRoutes(for: app)
    try createDataRoutes(for: app)
    try createDigestAuthRoute(for: app)
    try createDownloadRoutes(for: app)
    try createIPRoute(for: app)
    try createImageRoutes(for: app)
    try createInspectionRoutes(for: app)
    try createMethodRoutes(for: app)
    try createTLSRoutes(for: app)
    try createUploadRoutes(for: app)
    try createWebSocketRoutes(for: app)
    try createXMLRoute(for: app)
}
