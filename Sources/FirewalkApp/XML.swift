//
//  XML.swift
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

func createXMLRoute(for app: Application) throws {
    app.on(.GET, "xml") { request -> Response in
        let body = """
        <?xml version='1.0' encoding='us-ascii'?>
        <!--  A SAMPLE set of slides  -->
        <slideshow
          title="Sample Slide Show"
          date="Date of publication"
          author="Yours Truly"
          >
          <!-- TITLE SLIDE -->
          <slide type="all">
            <title>Wake up to WonderWidgets!</title>
          </slide>
          <!-- OVERVIEW -->
          <slide type="all">
            <title>Overview</title>
            <item>
              Why
              <em>WonderWidgets</em>
               are great
            </item>
            <item/>
            <item>
              Who
              <em>buys</em>
               WonderWidgets
            </item>
          </slide>
        </slideshow>
        """

        var buffer = request.application.allocator.buffer(capacity: body.utf8.count)
        buffer.writeString(body)

        let response = Response(body: .init(buffer: buffer))
        response.headers.replaceOrAdd(name: .contentType, value: "application/xml")
        return response
    }
}
