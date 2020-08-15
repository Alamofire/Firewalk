//
//  Images.swift
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

func createImageRoutes(for app: Application) throws {
    app.on(.GET, "image", ":type") { request -> Response in
        guard let type = request.parameters["type", as: String.self], ["jpeg", "png", "pdf", "heic"].contains(type),
              let path = Bundle.module.path(forResource: "image", ofType: type) else {
            return Response(status: .badRequest)
        }

        return request.fileio.streamFile(at: path)
    }

    // Vapor doesn't yet support resume ranges, so forward to original test file.
    app.on(.GET, "image", "large") { _ -> Response in
        let response = Response(status: .permanentRedirect)
        response.headers.replaceOrAdd(name: .location,
                                      value: "https://upload.wikimedia.org/wikipedia/commons/thumb/5/5f/HubbleDeepField.800px.jpg/2048px-HubbleDeepField.800px.jpg")

        return response
    }
}
