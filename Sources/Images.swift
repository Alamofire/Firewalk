//
//  Images.swift
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

func createImageRoutes(for app: Application) throws {
    app.on(.GET, "image", ":type") { request -> Response in
        guard let type = request.parameters["type", as: String.self], let image = Image(rawValue: type) else {
            return Response(status: .badRequest)
        }

        let response = Response(status: .ok)
        response.headers.contentType = image.contentType
        response.headers.contentDisposition = .init(.attachment, filename: image.suggestedFilename)

        let imageData = Data(base64Encoded: image.encodedImage)!
        response.body = .init(data: imageData)

        return response
    }
}

private enum Image: String, Decodable {
    case avif, bmp, jp2, jpeg, jxl, gif, heic, heif, pdf, png, tiff, webp

    var contentType: HTTPMediaType {
        switch self {
        case .avif:
            HTTPMediaType(type: "image", subType: "avif")
        case .bmp:
            HTTPMediaType(type: "image", subType: "x-ms-bmp")
        case .jp2:
            HTTPMediaType(type: "image", subType: "jp2")
        case .jpeg:
            .jpeg
        case .jxl:
            HTTPMediaType(type: "image", subType: "jxl")
        case .gif:
            .gif
        case .heic:
            HTTPMediaType(type: "image", subType: "heic")
        case .heif:
            HTTPMediaType(type: "image", subType: "heif")
        case .pdf:
            .pdf
        case .png:
            .png
        case .tiff:
            HTTPMediaType(type: "image", subType: "tiff")
        case .webp:
            HTTPMediaType(type: "image", subType: "webp")
        }
    }

    var encodedImage: String {
        switch self {
        case .avif:
            """
            AAAAIGZ0eXBhdmlmAAAAAGF2aWZtaWYxbWlhZk1BMUIAAADybWV0YQAAAAAAAAAoaGRscgAAAAAAAAAAcGljdAAAAAAAAAAAAAAAAGxpYmF\
            2aWYAAAAADnBpdG0AAAAAAAEAAAAeaWxvYwAAAABEAAABAAEAAAABAAABGgAAAB0AAAAoaWluZgAAAAAAAQAAABppbmZlAgAAAAABAABhdj\
            AxQ29sb3IAAAAAamlwcnAAAABLaXBjbwAAABRpc3BlAAAAAAAAAAIAAAACAAAAEHBpeGkAAAAAAwgICAAAAAxhdjFDgQ0MAAAAABNjb2xyb\
            mNseAACAAIAAYAAAAAXaXBtYQAAAAAAAAABAAEEAQKDBAAAACVtZGF0EgAKCBgANogQEAwgMg8f8D///8WfhwB8+ErK42A=
            """
        case .bmp:
            "Qk0eAAAAAAAAABoAAAAMAAAAAQABAAEAGAAAAP8A"
        case .jp2:
            """
            AAAADGpQICANCocKAAAAFGZ0eXBqcDIgAAAAAGpwMiAAAAAtanAyaAAAABZpaGRyAAAAAQAAAAEAAwcHAAAAAAAPY29scgEAAAAAABA\
            AAAAAanAyY/9P/1EALwAAAAAAAQAAAAEAAAAAAAAAAAAAAAEAAAABAAAAAAAAAAAAAwcBAQcBAQcBAf9cAA1AQEhIUEhIUEhIUP9SAA\
            wAAAABAQMEBAAB/2QADgABTFRfSlAyXzIyMP+QAAoAAAAAAB0AAf+T34AIB4CAgICAgICAgICA/9k=
            """
        case .jpeg:
            """
            /9j/2wBDAAMCAgICAgMCAgIDAwMDBAYEBAQEBAgGBgUGCQgKCgkICQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/yQALCAA\
            BAAEBAREA/8wABgAQEAX/2gAIAQEAAD8A0s8g/9k=
            """
        case .jxl:
            """
            /wo6HwGRCAYBAKQBC4ALbNQxslZLlFdAkOAPoAehB5BJcYD1Lo0WYXbZB4vCxGjuQc6x/4UgLq5cjpgHPfUXsGDCgv45dgEZBArgt1YI\
            436HAHKD5uNY+OGH8BV0jPMRJGl0oiUXUAHBDV4eWQQw6vhLEg4A
            """
        case .gif:
            "R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=="
        case .heic:
            """
            AAAAGGZ0eXBoZWljAAAAAGhlaWNtaWYxAAABtW1ldGEAAAAAAAAAImhkbHIAAAAAAAAAAHBpY3QAAAAAAAAAAAAAAAAAAAAAACRkaW5\
            mAAAAHGRyZWYAAAAAAAAAAQAAAAx1cmwgAAAAAQAAAA5waXRtAAAAAAABAAAAOGlpbmYAAAAAAAIAAAAVaW5mZQIAAAAAAQAAaHZjMQ\
            AAAAAVaW5mZQIAAAEAAgAARXhpZgAAAAAaaXJlZgAAAAAAAAAOY2RzYwACAAEAAQAAANdpcHJwAAAAt2lwY28AAAATY29scm5jbHgAA\
            gACAAaAAAAAb2h2Y0MBAWAAAACwAAAAAAAe8AD8/fj4AAAPA6AAAQAXQAEMAf//AWAAAAMAsAAAAwAAAwAeLAmhAAEAIkIBAQFgAAAD\
            ALAAAAMAAAMAHqAggQWcuSRIEuJuBAQNSASiAAEACEQBwGDUYikgAAAAFGlzcGUAAAAAAAAAQAAAAEAAAAAJaXJvdAAAAAAQcGl4aQA\
            AAAADCAgIAAAAGGlwbWEAAAAAAAAAAQABBYGCA4QFAAAALGlsb2MAAAAARAAAAgABAAAAAQAAAgEAAAA2AAIAAAABAAAB3QAAACQAAA\
            ABbWRhdAAAAAAAAABqAAAABkV4aWYAAE1NACoAAAAIAAEBEgADAAAAAQABAAAAAAAAAAAAMiYBrx9RH1wAAIvaQ7NuvDTJKZKZKZKZK\
            8K8K8K8K8K8K8K8+8h9YbnhyPHF8zZ/kV9X
            """
        case .heif:
            """
            AAAAGGZ0eXBoZWljAAAAAG1pZjFoZWljAAABKm1ldGEAAAAAAAAAIWhkbHIAAAAAAAAAAHBpY3QAXABjADEANQB4ADIAAAAADnBpdG0\
            AAAAAAAEAAAAiaWxvYwAAAABEQAABAAEAAAAAAUoAAQAAAAAAAAA4AAAAI2lpbmYAAAAAAAEAAAAVaW5mZQIAAAAAAQAAaHZjMQAAAA\
            CqaXBycAAAAI1pcGNvAAAAcWh2Y0MBBAgAAAAAAAAAAAD/8AD8/fj4AAAPAyAAAQAXQAEMAf//BAgAAAMAn6gAAAMAAP+6AkAhAAEAJ\
            kIBAQQIAAADAJ+oAAADAAD/oCCBBZbqSSiuAQAAAwABAAADAAEIIgABAAZEAcFxiRIAAAAUaXNwZQAAAAAAAABAAAAAQAAAABVpcG1h\
            AAAAAAAAAAEAAQKBAgAAAEBtZGF0AAAANCgBrwW4FIPqI0Af91/uf7X9b878787878989898989898989/4UETMJZQNe2nK06cUg1sA=
            """
        case .pdf:
            """
            JVBERi0xLgoxIDAgb2JqPDwvUGFnZXMgMiAwIFI+PmVuZG9iagoyIDAgb2JqPDwvS2lkc1szIDAgUl0vQ291bnQgMT4+ZW5kb2JqCjM\
            gMCBvYmo8PC9QYXJlbnQgMiAwIFI+PmVuZG9iagp0cmFpbGVyIDw8L1Jvb3QgMSAwIFI+Pg==
            """
        case .png:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg=="
        case .tiff:
            "TU0AKgAAAAgAAwEAAAMAAAABAAEAAAEBAAMAAAABAAEAAAERAAMAAAABAAAAAA=="
        case .webp:
            "UklGRhYAAABXRUJQVlA4TAkAAAAvAAAAAIiI/gcA"
        }
    }

    var suggestedFilename: String {
        "\(rawValue).\(rawValue)"
    }
}
