//
//  Compression.swift
//
//  Copyright (c) 2020-2026 Alamofire Software Foundation (http://alamofire.org/)
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

#if canImport(Compression)
import Compression
#endif
import CZlib
import Vapor

func createCompressionRoutes(for app: Application) throws {
    for encoding in ContentEncoding.allCases {
        app.on([.GET, .POST, .PUT, .PATCH, .DELETE], .constant(encoding.rawValue)) { request -> Response in
            guard encoding.isAvailable else { return Response(status: .notImplemented) }

            let reply = try JSONEncoder().encodeAsByteBuffer(Reply(to: request), allocator: request.byteBufferAllocator)
            let response = try Response(body: .init(buffer: encoding.encode(reply, allocator: request.byteBufferAllocator)))
            response.headers.contentType = .json
            response.headers.replaceOrAdd(name: .contentEncoding, value: encoding.token)
            return response
        }
    }
}

/// The encodings served at `/brotli`, `/gzip`, and `/deflate`, whose responses are always encoded, like httpbin.org's.
///
/// `gzip` and `deflate` use zlib. Brotli needs Apple's Compression framework, so other platforms respond to `/brotli`
/// with `501 Not Implemented`.
enum ContentEncoding: String, CaseIterable {
    case brotli, gzip, deflate

    struct EncodingFailed: Error {}

    /// The `Content-Encoding` value.
    var token: String {
        switch self {
        case .brotli: "br"
        case .gzip: "gzip"
        case .deflate: "deflate"
        }
    }

    /// Whether this platform can produce the encoding.
    var isAvailable: Bool {
        #if canImport(Compression)
        true
        #else
        self != .brotli
        #endif
    }

    /// Encodes the readable bytes of `input`. `deflate` is the zlib format of RFC 1950, as RFC 9110 specifies, and `gzip`
    /// is RFC 1952's.
    func encode(_ input: ByteBuffer, allocator: ByteBufferAllocator) throws(EncodingFailed) -> ByteBuffer {
        switch self {
        case .brotli:
            #if canImport(Compression)
            try Self.brotli(input, allocator: allocator)
            #else
            throw EncodingFailed()
            #endif
        case .deflate:
            try Self.zlib(input, windowBits: 15, allocator: allocator)
        case .gzip:
            // zlib writes a gzip header and trailer instead of its own when 16 is added to the window size.
            try Self.zlib(input, windowBits: 15 + 16, allocator: allocator)
        }
    }

    private static func zlib(_ input: ByteBuffer,
                             windowBits: Int32,
                             allocator: ByteBufferAllocator) throws(EncodingFailed) -> ByteBuffer {
        guard input.readableBytes <= UInt32.max else { throw EncodingFailed() }

        var stream = z_stream()
        guard deflateInit2_(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, windowBits, 8, Z_DEFAULT_STRATEGY,
                            ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            throw EncodingFailed()
        }
        defer { deflateEnd(&stream) }

        // Enough for one call to deflate to finish, however incompressible the input is.
        let capacity = Int(deflateBound(&stream, uLong(input.readableBytes)))
        return try allocator.buffer(capacity: capacity) { output throws(EncodingFailed) in
            let result = input.readableBytesUInt8Span.withUnsafeBufferPointer { input in
                output.withUnsafeMutableBytes { output, initializedCount in
                    // zlib only reads next_in, but declares it mutable unless every includer defines ZLIB_CONST.
                    stream.next_in = UnsafeMutablePointer(mutating: input.baseAddress)
                    stream.avail_in = uInt(input.count)
                    stream.next_out = output.bindMemory(to: Bytef.self).baseAddress
                    stream.avail_out = uInt(output.count)
                    let result = CZlib.deflate(&stream, Z_FINISH)
                    initializedCount = Int(stream.total_out)
                    return result
                }
            }
            guard result == Z_STREAM_END else { throw EncodingFailed() }
        }
    }

    #if canImport(Compression)
    private static func brotli(_ input: ByteBuffer, allocator: ByteBufferAllocator) throws(EncodingFailed) -> ByteBuffer {
        guard input.readableBytes > 0 else { throw EncodingFailed() }

        // Room for incompressible data, which Brotli stores with a few bytes of overhead per block.
        let capacity = input.readableBytes + input.readableBytes / 8 + 1024
        return try allocator.buffer(capacity: capacity) { output throws(EncodingFailed) in
            input.readableBytesUInt8Span.withUnsafeBufferPointer { input in
                output.withUnsafeMutableBytes { output, initializedCount in
                    initializedCount = compression_encode_buffer(output.bindMemory(to: UInt8.self).baseAddress!, output.count,
                                                                 input.baseAddress!, input.count,
                                                                 nil, COMPRESSION_BROTLI)
                }
            }
            guard output.byteCount > 0 else { throw EncodingFailed() }
        }
    }
    #endif
}
