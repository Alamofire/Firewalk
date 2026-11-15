//
//  CompressionTests.swift
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

#if canImport(Compression)
import Compression
#endif
@testable import firewalk
import CZlib
import Testing
import VaporTesting

struct CompressionTests {
    @Test(arguments: ContentEncoding.allCases.filter(\.isAvailable))
    func `responses are encoded replies`(encoding: ContentEncoding) async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "\(encoding.rawValue)?key=value", body: ByteBuffer(string: "body")) { response in
                #expect(response.status == .ok)
                #expect(response.headers.first(name: .contentEncoding) == encoding.token)
                #expect(response.headers.contentType == .json)

                let decoded = try decode(response.body, encoding)
                let reply = try JSONDecoder().decode(Reply.self, from: Data(decoded))
                #expect(reply.args == ["key": "value"])
                #expect(reply.data == "body")
            }
        }
    }

    @Test(arguments: ContentEncoding.allCases.filter { !$0.isAvailable })
    func `unavailable encodings aren't implemented`(encoding: ContentEncoding) async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, encoding.rawValue) { response in
                #expect(response.status == .notImplemented)
            }
        }
    }

    @Test
    func `deflate and gzip framing match their RFCs`() throws {
        let input = ByteBuffer(string: "Firewalk")

        let deflated = try Array(ContentEncoding.deflate.encode(input, allocator: .init()).readableBytesView)
        #expect((UInt16(deflated[0]) << 8 | UInt16(deflated[1])).isMultiple(of: 31))
        #expect(deflated[0] & 0x0F == 8)

        let gzipped = try Array(ContentEncoding.gzip.encode(input, allocator: .init()).readableBytesView)
        #expect(gzipped.prefix(3) == [0x1F, 0x8B, 0x08])
        #expect(gzipped.suffix(4) == [UInt8(input.readableBytes), 0, 0, 0])
    }

    /// Decodes with zlib, independently of the encoder, for `deflate` and `gzip`, and the Compression framework for
    /// Brotli. Replies are far smaller than the capacity used.
    private func decode(_ body: ByteBuffer, _ encoding: ContentEncoding) throws -> [UInt8] {
        let capacity = 1 << 20
        switch encoding {
        case .brotli:
            #if canImport(Compression)
            return [UInt8](capacity: capacity) { output in
                body.readableBytesUInt8Span.withUnsafeBufferPointer { input in
                    output.withUnsafeMutableBufferPointer { output, initializedCount in
                        initializedCount = compression_decode_buffer(output.baseAddress!, output.count,
                                                                     input.baseAddress!, input.count,
                                                                     nil, COMPRESSION_BROTLI)
                    }
                }
            }
            #else
            throw ContentEncoding.EncodingFailed()
            #endif
        case .deflate, .gzip:
            var stream = z_stream()
            // A window of 15 bits reads the zlib format, and adding 16 reads gzip's.
            try #require(inflateInit2_(&stream, encoding == .gzip ? 31 : 15, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK)
            defer { inflateEnd(&stream) }

            var result = Z_OK
            let decoded = [UInt8](capacity: capacity) { output in
                body.readableBytesUInt8Span.withUnsafeBufferPointer { input in
                    output.withUnsafeMutableBufferPointer { output, initializedCount in
                        stream.next_in = UnsafeMutablePointer(mutating: input.baseAddress)
                        stream.avail_in = uInt(input.count)
                        stream.next_out = output.baseAddress
                        stream.avail_out = uInt(output.count)
                        result = inflate(&stream, Z_FINISH)
                        initializedCount = Int(stream.total_out)
                    }
                }
            }
            try #require(result == Z_STREAM_END, "zlib couldn't decode the \(encoding) body: \(result)")

            return decoded
        }
    }
}
