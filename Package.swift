// swift-tools-version:5.8
//
//  Package.swift
//
//  Copyright (c) 2020-2022 Alamofire Software Foundation (http://alamofire.org/)
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

import PackageDescription

let swiftSettings: [SwiftSetting]
#if os(Linux)
swiftSettings = [.unsafeFlags(["-Xfrontend", "-validate-tbd-against-ir=none"])]
#else
swiftSettings = []
#endif

let package = Package(name: "Firewalk",
                      platforms: [.macOS(.v10_15)],
                      products: [.executable(name: "firewalk", targets: ["firewalk"])],
                      dependencies: [.package(url: "https://github.com/vapor/vapor.git", from: "4.86.0")],
                      targets: [.executableTarget(name: "firewalk",
                                                  dependencies: [.product(name: "Vapor", package: "vapor")],
                                                  path: "Sources",
                                                  swiftSettings: swiftSettings),
                                .testTarget(name: "FirewalkTests", dependencies: [.target(name: "firewalk"),
                                                                                  .product(name: "XCTVapor", package: "vapor")])])
