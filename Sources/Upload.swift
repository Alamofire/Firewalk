//
//  Upload.swift
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

func createUploadRoutes(for app: Application) throws {
    app.on(.POST, "upload", body: .stream) { request -> EventLoopFuture<Response> in
        let promise = request.eventLoop.makePromise(of: Response.self)

        let bytesReceived = Protected(0)
        request.body.drain { result in
            switch result {
            case let .buffer(buffer):
                bytesReceived.write { $0 += buffer.readableBytes }
                request.logger.info("Received \(bytesReceived) bytes so far.")
                return request.eventLoop.makeSucceededVoidFuture()
            case let .error(error):
                app.logger.report(error: error)
                return request.eventLoop.makeFailedFuture(error)
            case .end:
                app.logger.info("Upload of \(bytesReceived) bytes completed.")
                let response: Response
                do {
                    let uploadResponse = UploadResponse(bytes: bytesReceived.wrappedValue)
                    let buffer = try JSONEncoder().encodeAsByteBuffer(uploadResponse, allocator: request.application.allocator)
                    response = Response(status: .ok, body: .init(buffer: buffer))
                } catch {
                    app.logger.report(error: error)
                    response = Response(status: .internalServerError)
                }
                promise.succeed(response)

                return request.eventLoop.makeSucceededVoidFuture()
            }
        }

        return promise.futureResult
    }
}

struct UploadResponse: Encodable {
    let bytes: Int
}
