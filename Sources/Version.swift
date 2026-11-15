//
//  Version.swift
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

import Vapor

func createVersionRoute(for app: Application) throws {
    app.on(.GET, "version") { _ in
        VersionReply(version: Firewalk.version)
    }
}

/// Firewalk's version, with its components as numbers so clients can compare them directly.
struct VersionReply: Content, Equatable {
    let version: String
    let major: Int
    let minor: Int
    let patch: Int

    init(version: String) {
        let components = version.split(separator: ".").map { Int($0) }
        guard components.count == 3, let major = components[0], let minor = components[1], let patch = components[2] else {
            preconditionFailure("Firewalk.version '\(version)' must be in major.minor.patch form.")
        }

        self.version = version
        self.major = major
        self.minor = minor
        self.patch = patch
    }
}
