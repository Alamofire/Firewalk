//
//  DigestAuthTests.swift
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
import Dependencies
import Testing
import VaporTesting

@Suite(.dependency(\.date.now, Date(timeIntervalSince1970: 1_800_000_000)))
struct DigestAuthTests {
    private let path = "/digest-auth/auth/user/password"

    @Test
    func `request without credentials is challenged`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, path) { response in
                #expect(response.status == .unauthorized)
                #expect(response.body.readableBytes == 0)
                let challenge = try #require(response.headers.first(name: .wwwAuthenticate).flatMap(DigestCredentials.init))
                #expect(challenge["realm"] == DigestAuthMiddleware.realm)
                #expect(challenge["qop"] == "auth")
                #expect(challenge["algorithm"] == "MD5")
                #expect(challenge["charset"] == "UTF-8")
                #expect(challenge["stale"] == nil)
                #expect(challenge["userhash"] == nil)
                #expect(challenge["nonce"].flatMap(DigestNonce.issueDate) != nil)
            }
        }
    }

    @Test(arguments: [("auth", "MD5"), ("auth", "MD5-sess"), ("auth-int", "SHA-256"), ("auth-int", "SHA-256-sess"), ("none", "MD5")])
    func `valid credentials are accepted`(qop: String, algorithm: String) async throws {
        let path = "/digest-auth/\(qop)/user/password/\(algorithm)"
        try await withApp(configure: configure) { app in
            let challenge = try await challenge(for: path, in: app)
            let authorization = Client().authorization(answering: challenge, method: .POST, uri: path, body: "body")

            try await app.testing().test(.POST, path, headers: ["Authorization": authorization], body: ByteBuffer(string: "body")) { response in
                #expect(response.status == .ok)
                try #expect(response.reply().data == "body")
            }
        }
    }

    @Test
    func `invalid password is challenged again`() async throws {
        try await withApp(configure: configure) { app in
            let challenge = try await challenge(for: path, in: app)
            let authorization = Client(password: "wrong").authorization(answering: challenge, method: .GET, uri: path)

            try await expectChallenge(for: path, authorization: authorization, isStale: false, in: app)
        }
    }

    @Test
    func `nonce not issued by the server is rejected`() async throws {
        try await withApp(configure: configure) { app in
            let challenge = try await challenge(for: path, in: app)
            let forged = try #require(DigestCredentials(header: #"Digest realm="\#(DigestAuthMiddleware.realm)", nonce="\#(String(repeating: "0", count: 80))", opaque="\#(challenge["opaque"] ?? "")", qop="auth""#))
            let authorization = Client().authorization(answering: forged, method: .GET, uri: path)

            try await expectChallenge(for: path, authorization: authorization, isStale: false, in: app)
        }
    }

    @Test
    func `credentials for another URI are rejected`() async throws {
        try await withApp(configure: configure) { app in
            let challenge = try await challenge(for: path, in: app)
            let authorization = Client().authorization(answering: challenge, method: .GET, uri: "/digest-auth/auth/user/other")

            try await expectChallenge(for: path, authorization: authorization, isStale: false, in: app)
        }
    }

    @Test(arguments: ["/digest-auth/auth/user/password/SHA-1",
                      "/digest-auth/none/user/password/MD5-sess",
                      "/digest-auth/auth/user/password/MD5/0",
                      "/digest-auth/auth/user/password/MD5/soon"])
    func `invalid route parameters are a bad request`(path: String) async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, path) { response in
                #expect(response.status == .badRequest)
            }
        }
    }

    @Test
    func `nonce is stale after its lifetime`() async throws {
        let now = LockIsolated(Date(timeIntervalSince1970: 1_800_000_000))
        try await withDependencies {
            $0.date = DateGenerator { now.value }
        } operation: {
            try await withApp(configure: configure) { app in
                let challenge = try await challenge(for: path, in: app)
                now.withValue { $0 += DigestNonce.lifetime }

                let stale = try await expectChallenge(for: path,
                                                      authorization: Client().authorization(answering: challenge, method: .GET, uri: path),
                                                      isStale: true,
                                                      in: app)
                try await app.testing().test(.GET, path, headers: ["Authorization": Client().authorization(answering: stale, method: .GET, uri: path)]) { response in
                    #expect(response.status == .ok)
                }
            }
        }
    }

    @Test
    func `nonce is stale after its allowed uses`() async throws {
        let path = "/digest-auth/auth/user/password/MD5/1"
        try await withApp(configure: configure) { app in
            let challenge = try await challenge(for: path, in: app)
            try await app.testing().test(.GET, path, headers: ["Authorization": Client().authorization(answering: challenge, method: .GET, uri: path)]) { response in
                #expect(response.status == .ok)
            }

            try await expectChallenge(for: path,
                                      authorization: Client(nc: "00000002").authorization(answering: challenge, method: .GET, uri: path),
                                      isStale: true,
                                      in: app)
        }
    }

    @Test
    func `repeated nonce count is rejected as a replay`() async throws {
        try await withApp(configure: configure) { app in
            let challenge = try await challenge(for: path, in: app)
            let authorization = Client().authorization(answering: challenge, method: .GET, uri: path)
            try await app.testing().test(.GET, path, headers: ["Authorization": authorization]) { response in
                #expect(response.status == .ok)
            }

            try await expectChallenge(for: path, authorization: authorization, isStale: false, in: app)
        }
    }

    @Test
    func `nonce counts can arrive out of order`() async throws {
        try await withApp(configure: configure) { app in
            let challenge = try await challenge(for: path, in: app)
            for nc in ["00000002", "00000001"] {
                try await app.testing().test(.GET, path, headers: ["Authorization": Client(nc: nc).authorization(answering: challenge, method: .GET, uri: path)]) { response in
                    #expect(response.status == .ok)
                }
            }
        }
    }

    @Test
    func `malformed nonce count is rejected`() async throws {
        try await withApp(configure: configure) { app in
            let challenge = try await challenge(for: path, in: app)
            for nc in ["1", "+0000001", "0000000g"] {
                let authorization = Client(nc: nc).authorization(answering: challenge, method: .GET, uri: path)
                try await expectChallenge(for: path, authorization: authorization, isStale: false, in: app)
            }
        }
    }

    @Test
    func `hashed username is accepted and can be advertised`() async throws {
        let path = "/digest-auth/auth/user/password?userhash=true"
        try await withApp(configure: configure) { app in
            let challenge = try await challenge(for: path, in: app)
            #expect(challenge["userhash"] == "true")

            let authorization = Client(usesUserhash: true).authorization(answering: challenge, method: .GET, uri: path)
            try await app.testing().test(.GET, path, headers: ["Authorization": authorization]) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test
    func `hashed username for another user is rejected`() async throws {
        try await withApp(configure: configure) { app in
            let challenge = try await challenge(for: path, in: app)
            let authorization = Client(user: "other", usesUserhash: true).authorization(answering: challenge, method: .GET, uri: path)

            try await expectChallenge(for: path, authorization: authorization, isStale: false, in: app)
        }
    }

    @Test
    func `extended username is decoded`() async throws {
        let path = "/digest-auth/auth/J%C3%A4s%C3%B8n/password"
        try await withApp(configure: configure) { app in
            let challenge = try await challenge(for: path, in: app)
            let authorization = Client(user: "Jäsøn", usesExtendedUsername: true).authorization(answering: challenge, method: .GET, uri: path)

            try await app.testing().test(.GET, path, headers: ["Authorization": authorization]) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test
    func `nonces issued at the same time differ`() {
        let first = DigestNonce.make(), second = DigestNonce.make()

        #expect(first != second)
        #expect(DigestNonce.issueDate(of: first) == Date(timeIntervalSince1970: 1_800_000_000))
        #expect(DigestNonce.issueDate(of: second) == Date(timeIntervalSince1970: 1_800_000_000))
    }

    @Test
    func `repeated or unnamed parameters are malformed`() {
        #expect(DigestCredentials(header: #"Digest username="a", username="b""#) == nil)
        #expect(DigestCredentials(header: #"Digest username="a", USERNAME="b""#) == nil)
        #expect(DigestCredentials(header: #"Digest ="a""#) == nil)
    }

    @Test
    func `uppercase hashed username is accepted`() async throws {
        try await withApp(configure: configure) { app in
            let challenge = try await challenge(for: path, in: app)
            let authorization = Client(usesUserhash: true).authorization(answering: challenge, method: .GET, uri: path)
            let uppercased = try authorization.replacing(#/username="([0-9a-f]+)"/#) { #"username="\#($0.output.1.uppercased())""# }

            try await app.testing().test(.GET, path, headers: ["Authorization": uppercased]) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test
    func `nonce is stale after its maximum counts`() throws {
        let nonces = DigestNonceStore()
        let nonce = DigestNonce.make()
        let issued = try #require(DigestNonce.issueDate(of: nonce))

        for count in 1...UInt32(DigestNonceStore.maximumCounts) {
            guard nonces.use(nonce, issued: issued, count: count, staleAfter: nil) == .accepted else {
                Issue.record("count \(count) wasn't accepted")
                return
            }
        }

        #expect(nonces.use(nonce, issued: issued, count: UInt32(DigestNonceStore.maximumCounts) + 1, staleAfter: nil) == .stale)
    }

    @Test
    func `constant time comparison matches only equal strings`() {
        #expect(constantTimeEquals("abc123", "abc123"))
        #expect(!constantTimeEquals("abc123", "abc124"))
        #expect(!constantTimeEquals("abc123", "abc12"))
        #expect(constantTimeEquals("", ""))
    }

    @Test
    func `quoted parameters can contain commas and escapes`() throws {
        let credentials = try #require(DigestCredentials(header: #"Digest username="a\"b,c", realm=r, nc=00000001"#))

        #expect(credentials["username"] == #"a"b,c"#)
        #expect(credentials["realm"] == "r")
        #expect(credentials["nc"] == "00000001")
    }

    @Test
    func `hex encoding round trips`() {
        let bytes: [UInt8] = [0x00, 0x0F, 0xA0, 0xFF, 0x12]

        #expect(bytes.hexString == "000fa0ff12")
        #expect([UInt8](hexString: "000fa0ff12") == bytes)
        #expect([UInt8](hexString: "000FA0FF12") == bytes)
        #expect([UInt8](hexString: "0g") == nil)
        #expect([UInt8](hexString: "abc") == nil)
    }

    private func challenge(for path: String, in app: Application) async throws -> DigestCredentials {
        var challenge: DigestCredentials?
        try await app.testing().test(.GET, path) { response in
            challenge = response.headers.first(name: .wwwAuthenticate).flatMap(DigestCredentials.init)
        }

        return try #require(challenge)
    }

    /// Expects a `401` with a new challenge for `authorization`, and returns that challenge.
    @discardableResult
    private func expectChallenge(for path: String,
                                 authorization: String,
                                 isStale: Bool,
                                 in app: Application) async throws -> DigestCredentials {
        var challenge: DigestCredentials?
        try await app.testing().test(.GET, path, headers: ["Authorization": authorization]) { response in
            #expect(response.status == .unauthorized)
            challenge = response.headers.first(name: .wwwAuthenticate).flatMap(DigestCredentials.init)
        }
        let newChallenge = try #require(challenge)
        #expect((newChallenge["stale"] == "true") == isStale)

        return newChallenge
    }
}

/// Computes `Authorization` headers the way a client does, independently of the middleware.
private struct Client {
    var user = "user"
    var password = "password"
    var nc = "00000001"
    var usesUserhash = false
    var usesExtendedUsername = false

    func authorization(answering challenge: DigestCredentials, method: HTTPMethod, uri: String, body: String = "") -> String {
        let algorithm = challenge["algorithm"] ?? "MD5"
        func hash(_ string: String) -> String {
            algorithm.hasPrefix("SHA-256") ? SHA256.hash(data: Data(string.utf8)).hexString : Insecure.MD5.hash(data: Data(string.utf8)).hexString
        }

        let realm = challenge["realm"] ?? "", nonce = challenge["nonce"] ?? "", cnonce = "0a4f113b"
        var ha1 = hash("\(user):\(realm):\(password)")
        if algorithm.hasSuffix("-sess") {
            ha1 = hash("\(ha1):\(nonce):\(cnonce)")
        }

        let username = if usesUserhash {
            #"username="\#(hash("\(user):\(realm)"))", userhash=true"#
        } else if usesExtendedUsername {
            "username*=UTF-8''\(user.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? user)"
        } else {
            #"username="\#(user)""#
        }
        var header = #"Digest \#(username), realm="\#(realm)", nonce="\#(nonce)", uri="\#(uri)", algorithm=\#(algorithm), opaque="\#(challenge["opaque"] ?? "")""#
        guard let qop = challenge["qop"] else {
            return header + #", response="\#(hash("\(ha1):\(nonce):\(hash("\(method.rawValue):\(uri)"))"))""#
        }

        let ha2 = qop == "auth-int" ? hash("\(method.rawValue):\(uri):\(hash(body))") : hash("\(method.rawValue):\(uri)")
        let response = hash("\(ha1):\(nonce):\(nc):\(cnonce):\(qop):\(ha2)")
        header += #", qop=\#(qop), nc=\#(nc), cnonce="\#(cnonce)", response="\#(response)""#

        return header
    }
}
