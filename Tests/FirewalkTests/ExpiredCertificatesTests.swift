//
//  ExpiredCertificatesTests.swift
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

@testable import firewalk
import Foundation
import Testing
import X509

struct ExpiredCertificatesTests {
    @Test
    func `chain is ordered, expired at the leaf, and servable`() throws {
        let leaf = try Certificate(pemEncoded: ExpiredCertificates.leaf)
        let intermediate2 = try Certificate(pemEncoded: ExpiredCertificates.intermediate2)
        let intermediate1 = try Certificate(pemEncoded: ExpiredCertificates.intermediate1)
        let root = try Certificate(pemEncoded: ExpiredCertificates.root)

        #expect(leaf.issuer == intermediate2.subject)
        #expect(intermediate2.issuer == intermediate1.subject)
        #expect(intermediate1.issuer == root.subject)
        #expect(root.issuer == root.subject)
        #expect(leaf.notValidAfter < Date())
        #expect(root.notValidAfter > Date())
        _ = try ExpiredCertificates.serverConfiguration()
    }
}
