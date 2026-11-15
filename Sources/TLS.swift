//
//  TLS.swift
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

import NIOSSL
import SwiftASN1
import Vapor
import X509

/// Self-signed TLS identity for `localhost`, generated once per launch and shared by all TLS servers.
enum TLSIdentity {
    static let shared: (certificate: [UInt8], privateKey: P256.Signing.PrivateKey) = {
        do {
            return try make()
        } catch {
            fatalError("Failed to generate TLS identity: \(error)")
        }
    }()

    /// `TLSConfiguration` using the shared identity. ALPN protocols are added by `HTTPServer` based on its
    /// `supportVersions`.
    static func serverConfiguration() throws -> TLSConfiguration {
        let identity = shared
        let certificate = try NIOSSLCertificate(bytes: identity.certificate, format: .der)
        let privateKey = try NIOSSLPrivateKey(bytes: Array(identity.privateKey.derRepresentation), format: .der)

        return .makeServerConfiguration(certificateChain: [.certificate(certificate)], privateKey: .privateKey(privateKey))
    }

    private static func make() throws -> (certificate: [UInt8], privateKey: P256.Signing.PrivateKey) {
        let privateKey = P256.Signing.PrivateKey()
        let name = try DistinguishedName {
            CommonName("localhost")
            OrganizationName("Firewalk")
        }
        let now = Date()
        let certificate = try Certificate(version: .v3,
                                          // SerialNumber() crashes when built with Thread Sanitizer, so the bytes are made here.
                                          serialNumber: .init(bytes: (0..<20).map { _ in UInt8.random(in: 1...0x7F) }),
                                          publicKey: .init(privateKey.publicKey),
                                          notValidBefore: now.addingTimeInterval(-60 * 60),
                                          // Apple platforms reject TLS server certificates valid for more than 825 days.
                                          notValidAfter: now.addingTimeInterval(365 * 24 * 60 * 60),
                                          issuer: name,
                                          subject: name,
                                          signatureAlgorithm: .ecdsaWithSHA256,
                                          extensions: Certificate.Extensions {
                                              Critical(BasicConstraints.notCertificateAuthority)
                                              Critical(KeyUsage(digitalSignature: true))
                                              try ExtendedKeyUsage([.serverAuth])
                                              SubjectAlternativeNames([.dnsName("localhost"),
                                                                       .ipAddress(ASN1OctetString(contentBytes: [127, 0, 0, 1])),
                                                                       .ipAddress(ASN1OctetString(contentBytes: [0, 0, 0, 0, 0, 0, 0, 0,
                                                                                                                 0, 0, 0, 0, 0, 0, 0, 1]))])
                                          },
                                          issuerPrivateKey: .init(privateKey))
        var serializer = DER.Serializer()
        try serializer.serialize(certificate)

        return (serializer.serializedBytes, privateKey)
    }
}

extension ExpiredCertificates {
    /// `TLSConfiguration` presenting the whole expired chain, including the root, so clients can pin any of them.
    static func serverConfiguration() throws -> TLSConfiguration {
        let chain = try [leaf, intermediate2, intermediate1, root].map {
            try NIOSSLCertificateSource.certificate(NIOSSLCertificate(bytes: Array($0.utf8), format: .pem))
        }
        let privateKey = try NIOSSLPrivateKey(bytes: Array(leafPrivateKey.utf8), format: .pem)

        return .makeServerConfiguration(certificateChain: chain, privateKey: .privateKey(privateKey))
    }
}

func createTLSRoutes(for app: Application) throws {
    // DER encoded certificate used by TLS servers, so clients can pin or trust it.
    app.on(.GET, "tls", "certificate") { _ -> Response in
        Response(status: .ok,
                 headers: ["Content-Type": "application/pkix-cert"],
                 body: .init(data: Data(TLSIdentity.shared.certificate)))
    }
}
