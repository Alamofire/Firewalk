//
//  DigestAuth.swift
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

import Dependencies
import Synchronization
import Vapor

func createDigestAuthRoute(for app: Application) throws {
    let digestAuth = app.grouped(DigestAuthMiddleware())
    let handler: @Sendable (Request) async throws -> Response = { request in
        try await Reply(to: request).encodeResponse(for: request)
    }
    let methods: [HTTPMethod] = [.GET, .POST, .PUT, .PATCH, .DELETE]
    digestAuth.on(methods, "digest-auth", ":qop", ":user", ":passwd", use: handler)
    digestAuth.on(methods, "digest-auth", ":qop", ":user", ":passwd", ":algorithm", use: handler)
    digestAuth.on(methods, "digest-auth", ":qop", ":user", ":passwd", ":algorithm", ":staleAfter", use: handler)
}

/// HTTP digest authentication, per RFC 7616, against the `user` and `passwd` path parameters, like httpbin.org's
/// `/digest-auth/{qop}/{user}/{passwd}/{algorithm}/{stale_after}`.
///
/// - `qop` is `auth` or `auth-int`. Any other value challenges without a `qop`, as RFC 2069 did.
/// - `algorithm` is `MD5`, the default, `MD5-sess`, `SHA-256`, or `SHA-256-sess`. The `-sess` algorithms need a `qop`,
///   since they hash the client's `cnonce`.
/// - `staleAfter` is how many requests a nonce authenticates before it's stale, or `never`, the default.
/// - A `userhash=true` query parameter advertises `userhash` support. Hashed usernames are accepted either way, as are
///   RFC 8187 encoded `username*` values.
///
/// Nonces are stale after `DigestNonce.lifetime`, or `DigestNonceStore.maximumCounts` requests. Requests with valid
/// credentials and a stale nonce receive a `401` with `stale=true` and a new nonce, which clients use without asking for
/// credentials again. A repeated `nc` for a nonce is rejected as a replay. Without a `qop` there's no `nc`, so only
/// `staleAfter` limits replays. Other requests without valid credentials receive a `401` with an empty body and a new
/// challenge.
struct DigestAuthMiddleware: AsyncMiddleware {
    static let realm = "firewalk@alamofire.org"
    static let opaque = "6669726577616c6b6f706171756564"

    /// Used nonces, for this middleware's `Application` alone.
    let nonces = DigestNonceStore()

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard let user = request.parameters.get("user"),
              let password = request.parameters.get("passwd"),
              let qop = request.parameters.get("qop"),
              let algorithm = DigestAlgorithm(request.parameters.get("algorithm") ?? DigestAlgorithm.md5.rawValue),
              let staleAfter = DigestStaleAfter(request.parameters.get("staleAfter") ?? "never") else {
            return Response(status: .badRequest)
        }

        let challenge = DigestChallenge(qop: DigestChallenge.supportedQOPs.contains(qop) ? qop : nil,
                                        algorithm: algorithm,
                                        staleAfter: staleAfter.uses,
                                        advertisesUserhash: request.query[String.self, at: "userhash"] == "true")
        guard challenge.qop != nil || !algorithm.isSession else { return Response(status: .badRequest) }

        guard let credentials = request.headers.first(name: .authorization).flatMap(DigestCredentials.init),
              let issued = challenge.issueDate(of: credentials, user: user, for: request) else {
            return challenge.response(isStale: false)
        }

        // Routes collect the body only after their middleware runs, so a body that arrived in more than one part isn't
        // available to hash yet. Collected only for credentials that passed every check but the response itself.
        if challenge.qop == "auth-int", request.body.data == nil {
            _ = try await request.body.collect(max: request.application.routes.defaultMaxBodySize.value).get()
        }

        switch challenge.verify(credentials, issued: issued, user: user, password: password, for: request, nonces: nonces) {
        case .accepted: return try await next.respond(to: request)
        case .stale: return challenge.response(isStale: true)
        case .rejected: return challenge.response(isStale: false)
        }
    }
}

enum DigestAlgorithm: String, CaseIterable {
    case md5 = "MD5"
    case md5Session = "MD5-sess"
    case sha256 = "SHA-256"
    case sha256Session = "SHA-256-sess"

    init?(_ name: String) {
        guard let algorithm = Self.allCases.first(where: { $0.rawValue.caseInsensitiveCompare(name) == .orderedSame }) else {
            return nil
        }

        self = algorithm
    }

    var isSession: Bool {
        self == .md5Session || self == .sha256Session
    }

    func hash(_ string: String) -> String {
        var string = string
        return string.withUTF8 { hash(UnsafeRawBufferPointer($0)) }
    }

    func hash(_ bytes: UnsafeRawBufferPointer) -> String {
        switch self {
        case .md5, .md5Session: Insecure.MD5.hash(data: bytes).hexString
        case .sha256, .sha256Session: SHA256.hash(data: bytes).hexString
        }
    }
}

/// The `staleAfter` path parameter: a positive number of uses, or `never`.
struct DigestStaleAfter {
    let uses: Int?

    init?(_ value: String) {
        if value == "never" {
            uses = nil
        } else if let uses = Int(value), uses > 0 {
            self.uses = uses
        } else {
            return nil
        }
    }
}

struct DigestChallenge {
    enum Verification { case accepted, stale, rejected }

    static let supportedQOPs: Set<String> = ["auth", "auth-int"]

    let qop: String?
    let algorithm: DigestAlgorithm
    let staleAfter: Int?
    let advertisesUserhash: Bool

    func response(isStale: Bool) -> Response {
        Response(status: .unauthorized, headers: ["WWW-Authenticate": header(isStale: isStale)])
    }

    func header(isStale: Bool) -> String {
        var parameters = ["realm=\"\(DigestAuthMiddleware.realm)\"",
                          "nonce=\"\(DigestNonce.make())\"",
                          "opaque=\"\(DigestAuthMiddleware.opaque)\"",
                          "algorithm=\(algorithm.rawValue)",
                          "charset=UTF-8"]
        if let qop {
            parameters.append("qop=\"\(qop)\"")
        }
        if advertisesUserhash {
            parameters.append("userhash=true")
        }
        if isStale {
            parameters.append("stale=true")
        }

        return "Digest \(parameters.joined(separator: ", "))"
    }

    /// Checks everything but the response, which can need the body, and returns when the nonce was issued.
    func issueDate(of credentials: DigestCredentials, user: String, for request: Request) -> Date? {
        guard credentials.plainUsername == user ||
            (credentials["userhash"] == "true" &&
                credentials["username"]?.lowercased() == algorithm.hash("\(user):\(DigestAuthMiddleware.realm)")),
            credentials["realm"] == DigestAuthMiddleware.realm,
            credentials["opaque"] == DigestAuthMiddleware.opaque,
            DigestAlgorithm(credentials["algorithm"] ?? DigestAlgorithm.md5.rawValue) == algorithm,
            credentials["uri"] == request.url.string,
            credentials["response"] != nil,
            let nonce = credentials["nonce"] else { return nil }

        return DigestNonce.issueDate(of: nonce)
    }

    /// Checks the response of credentials that passed `issueDate(of:user:for:)`, and records the nonce's use.
    func verify(_ credentials: DigestCredentials,
                issued: Date,
                user: String,
                password: String,
                for request: Request,
                nonces: DigestNonceStore) -> Verification {
        guard let nonce = credentials["nonce"], let response = credentials["response"] else { return .rejected }

        var ha1 = algorithm.hash("\(user):\(DigestAuthMiddleware.realm):\(password)")
        var ha2Input = "\(request.method.rawValue):\(request.url.string)"
        let expected: String
        let nonceCount: UInt32?
        if let qop {
            guard credentials["qop"] == qop,
                  let nc = credentials["nc"], let count = DigestNonce.count(nc),
                  let clientNonce = credentials["cnonce"] else { return .rejected }

            if algorithm.isSession {
                ha1 = algorithm.hash("\(ha1):\(nonce):\(clientNonce)")
            }
            if qop == "auth-int" {
                let bodyHash = request.body.data?.withUnsafeReadableBytes { algorithm.hash($0) } ?? algorithm.hash("")
                ha2Input += ":\(bodyHash)"
            }
            expected = algorithm.hash("\(ha1):\(nonce):\(nc):\(clientNonce):\(qop):\(algorithm.hash(ha2Input))")
            nonceCount = count
        } else {
            expected = algorithm.hash("\(ha1):\(nonce):\(algorithm.hash(ha2Input))")
            nonceCount = nil
        }

        guard constantTimeEquals(response.lowercased(), expected) else { return .rejected }

        return nonces.use(nonce, issued: issued, count: nonceCount, staleAfter: staleAfter)
    }
}

/// Nonces carry their creation time, random bytes so nonces issued at the same time differ, and an HMAC of both, so the
/// server recognizes its own without storing them until they're used. `DigestNonceStore` tracks used nonces.
enum DigestNonce {
    /// How long a nonce authenticates requests before it's stale.
    static let lifetime: TimeInterval = 300

    private static let key = SymmetricKey(size: .bits256)

    static func make() -> String {
        @Dependency(\.date.now) var now
        var message = withUnsafeBytes(of: UInt64(now.timeIntervalSince1970 * 1000).bigEndian) { Array($0) }
        message += (0..<8).map { _ in UInt8.random(in: .min ... .max) }

        return message.hexString + Array(HMAC<SHA256>.authenticationCode(for: message, using: key)).hexString
    }

    /// When `nonce` was issued, or `nil` if this server didn't issue it.
    static func issueDate(of nonce: String) -> Date? {
        guard let bytes = [UInt8](hexString: nonce), bytes.count > 16 else { return nil }

        let message = Array(bytes.prefix(16))
        let isValid = message.withUnsafeBytes { message in
            HMAC<SHA256>.isValidAuthenticationCode(Array(bytes.dropFirst(16)), authenticating: message, using: key)
        }
        guard isValid else { return nil }

        let milliseconds = message.prefix(8).reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        return Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }

    /// The value of an `nc` parameter, exactly eight hexadecimal digits.
    static func count(_ nc: String) -> UInt32? {
        guard nc.utf8.count == 8, nc.utf8.allSatisfy(\.isHexDigit) else { return nil }

        return UInt32(nc, radix: 16)
    }
}

/// Nonces whose credentials were valid, tracked until they expire to count their uses and reject repeated `nc` values.
final class DigestNonceStore: Sendable {
    /// The most `nc` values recorded for a nonce, which bounds memory. Clients are then sent a new nonce.
    static let maximumCounts = 10_000

    private struct Entry {
        let issued: Date
        var uses = 0
        var counts: Set<UInt32> = []
    }

    private struct State {
        var entries: [String: Entry] = [:]
        var lastPruned = Date.distantPast
    }

    private let state = Mutex(State())

    /// Records a use of an issued `nonce` whose credentials are otherwise valid.
    func use(_ nonce: String, issued: Date, count: UInt32?, staleAfter: Int?) -> DigestChallenge.Verification {
        @Dependency(\.date.now) var now
        guard now.timeIntervalSince(issued) < DigestNonce.lifetime else { return .stale }

        return state.withLock { state in
            if now.timeIntervalSince(state.lastPruned) > 60 {
                state.entries = state.entries.filter { now.timeIntervalSince($0.value.issued) < DigestNonce.lifetime }
                state.lastPruned = now
            }

            var entry = state.entries[nonce] ?? Entry(issued: issued)
            if let staleAfter, entry.uses >= staleAfter {
                return .stale
            }
            if entry.counts.count >= Self.maximumCounts {
                return .stale
            }
            // Concurrent requests can arrive out of order, so any unused count is accepted, not only increasing ones.
            if let count, !entry.counts.insert(count).inserted {
                return .rejected
            }
            entry.uses += 1
            state.entries[nonce] = entry

            return .accepted
        }
    }
}

/// Compares in time that depends only on the lengths, so response timing doesn't reveal how much of a guess matched.
func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
    let lhs = Array(lhs.utf8), rhs = Array(rhs.utf8)
    guard lhs.count == rhs.count else { return false }

    var difference: UInt8 = 0
    for index in lhs.indices {
        difference |= lhs[index] ^ rhs[index]
    }

    return difference == 0
}

/// The parameters of a `Digest` `Authorization` header, with names lowercased.
struct DigestCredentials {
    private let parameters: [String: String]

    init?(header: String) {
        guard header.prefix(7).lowercased() == "digest ", !header.dropFirst(7).isEmpty else { return nil }

        var parameters: [String: String] = [:]
        var remaining = header.dropFirst(7)
        while true {
            remaining = remaining.drop { $0 == " " || $0 == "\t" || $0 == "," }
            guard !remaining.isEmpty else { break }
            guard let equals = remaining.firstIndex(of: "=") else { return nil }

            let name = remaining[..<equals].trimmingCharacters(in: .whitespaces).lowercased()
            // Parameters can't repeat, per RFC 7616, so a repeat is malformed rather than ambiguous.
            guard !name.isEmpty, parameters[name] == nil else { return nil }
            remaining = remaining[remaining.index(after: equals)...].drop { $0 == " " || $0 == "\t" }
            var value = ""
            if remaining.first == "\"" {
                remaining = remaining.dropFirst()
                var isEscaped = false
                var isClosed = false
                while let character = remaining.popFirst() {
                    if isEscaped {
                        value.append(character)
                        isEscaped = false
                    } else if character == "\\" {
                        isEscaped = true
                    } else if character == "\"" {
                        isClosed = true
                        break
                    } else {
                        value.append(character)
                    }
                }
                guard isClosed else { return nil }
            } else {
                let end = remaining.firstIndex(of: ",") ?? remaining.endIndex
                value = remaining[..<end].trimmingCharacters(in: .whitespaces)
                remaining = remaining[end...]
            }
            parameters[name] = value
        }

        self.parameters = parameters
    }

    subscript(name: String) -> String? {
        parameters[name]
    }
}

private let hexDigits = Array("0123456789abcdef".utf8)

extension UInt8 {
    var isHexDigit: Bool {
        (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(self) ||
            (UInt8(ascii: "a")...UInt8(ascii: "f")).contains(self) ||
            (UInt8(ascii: "A")...UInt8(ascii: "F")).contains(self)
    }
}

extension Sequence<UInt8> {
    /// Lowercase hexadecimal, as digests are written.
    var hexString: String {
        var digits: [UInt8] = []
        digits.reserveCapacity(underestimatedCount * 2)
        for byte in self {
            digits.append(hexDigits[Int(byte >> 4)])
            digits.append(hexDigits[Int(byte & 0x0F)])
        }

        return String(decoding: digits, as: UTF8.self)
    }
}

extension [UInt8] {
    init?(hexString: String) {
        let digits = Array(hexString.utf8)
        guard digits.count.isMultiple(of: 2) else { return nil }

        func value(of digit: UInt8) -> UInt8? {
            switch digit {
            case UInt8(ascii: "0")...UInt8(ascii: "9"): digit - UInt8(ascii: "0")
            case UInt8(ascii: "a")...UInt8(ascii: "f"): digit - UInt8(ascii: "a") + 10
            case UInt8(ascii: "A")...UInt8(ascii: "F"): digit - UInt8(ascii: "A") + 10
            default: nil
            }
        }

        var bytes: [UInt8] = []
        bytes.reserveCapacity(digits.count / 2)
        for index in stride(from: 0, to: digits.count, by: 2) {
            guard let high = value(of: digits[index]), let low = value(of: digits[index + 1]) else { return nil }
            bytes.append(high << 4 | low)
        }

        self = bytes
    }
}

extension DigestCredentials {
    /// The plain username: `username*` decoded per RFC 8187 when present, otherwise `username` unless it's hashed.
    var plainUsername: String? {
        if let extended = self["username*"] {
            let parts = extended.split(separator: "'", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count == 3, parts[0].caseInsensitiveCompare("UTF-8") == .orderedSame else { return nil }

            return String(parts[2]).removingPercentEncoding
        }

        return self["userhash"] == "true" ? nil : self["username"]
    }
}
