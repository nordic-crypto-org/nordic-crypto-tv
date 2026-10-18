#if os(iOS)
import CryptoKit
import Foundation
import Observation
import Security

/// Staff-only admin screen: the same read-only data as nordiccrypto.no/admin/, from the tip Worker
/// (nordic-crypto tipworker/src/admin.js). Sign-in: an emailed 8-digit code bound to a PKCE-style
/// challenge; the bearer session lives only in the Keychain, admin data only in memory.
enum AdminConfig {
    static let api = URL(string: "https://nordic-crypto-tips.nordiccrypto.workers.dev/api/admin/")!
    /// Public release list (no addresses), the same file the web admin shows.
    static let pressHistory = URL(string: "https://raw.githubusercontent.com/nordic-crypto-org/nordic-crypto/main/data/press/history.json")!
    static let domain = "nordiccrypto.no"
}

/// The Worker's allowedAdmin rule: one "@", a plain local part, the domain exactly nordiccrypto.no.
enum AdminEmail {
    private static let localChars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.!#$%&'*+/=?^_`{|}~-")

    static func normalized(_ raw: String) -> String? {
        let e = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard e.count <= 254, !e.contains(where: \.isWhitespace) else { return nil }
        let parts = e.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[1] == AdminConfig.domain else { return nil }
        let local = parts[0]
        guard (1...64).contains(local.count), local.unicodeScalars.allSatisfy(localChars.contains),
              !local.hasPrefix("."), !local.hasSuffix("."), !local.contains("..") else { return nil }
        return e
    }
}

enum AdminCode {
    /// "1234 5678" or "1234-5678" -> "12345678"; anything else nil.
    static func normalized(_ raw: String) -> String? {
        let d = raw.filter { !$0.isWhitespace && $0 != "-" }
        return d.count == 8 && d.allSatisfy({ $0.isASCII && $0.isNumber }) ? d : nil
    }
}

struct AdminPKCE {
    let verifier: String
    var challenge: String { Self.challenge(for: verifier) }

    init(verifier: String = AdminPKCE.randomVerifier()) { self.verifier = verifier }

    static func randomVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        precondition(SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess)
        return base64url(Data(bytes))
    }

    static func challenge(for verifier: String) -> String {
        base64url(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    static func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

struct AdminSession: Codable, Equatable {
    let token: String
    let email: String
    let expires: TimeInterval

    var isValid: Bool { expires > Date().timeIntervalSince1970 }
}

/// This device only, after first unlock is not enough: readable only while unlocked, never synced or backed up.
struct AdminKeychain {
    var service = "no.cryptonordic.tv.admin"
    var account = "session"

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    func load() -> AdminSession? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return try? JSONDecoder().decode(AdminSession.self, from: data)
    }

    func save(_ session: AdminSession) {
        delete()
        guard let data = try? JSONEncoder().encode(session) else { return }
        var q = query
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }

    func delete() {
        SecItemDelete(query as CFDictionary)
    }
}

struct AdminSubscriber: Decodable, Identifiable, Hashable {
    let id: Int
    let email: String
    let lang: String?
    let status: String
    let createdAt: String?
    let confirmedAt: String?
    let issues: [Int]
    let lastIssue: Int?
}

struct AdminTotals: Decodable, Equatable {
    let all: Int
    let pending: Int
    let confirmed: Int
    let unsubscribed: Int
    let deliveries: Int
}

struct AdminSubscribers: Decodable {
    let email: String
    let rows: [AdminSubscriber]
    let totals: AdminTotals
    let lastIssue: Int?
}

struct AdminPressSend: Decodable, Identifiable {
    struct Recipient: Decodable, Hashable {
        let email: String
        let status: String
        let error: String?
    }

    let id: String
    let releaseId: String
    let at: String
    let fromAddr: String
    let dryRun: Bool
    let sent: Int
    let failed: Int
    let recipients: [Recipient]
}

struct AdminPressSends: Decodable {
    let sends: [AdminPressSend]
}

struct PressRelease: Decodable, Identifiable {
    let id: String
    let title: String?
    let languages: [String]?
    let published: String?
    let link: String?
    let status: String?
    let emailsSent: Int?
}

struct PressHistory: Decodable {
    let releases: [PressRelease]
}

enum AdminSort: String, CaseIterable, Identifiable {
    case newest = "Newest", email = "Email", lastIssue = "Last issue"
    var id: String { rawValue }
}

enum AdminFilter {
    /// The web admin's filter: status, then a case-insensitive match on email, language, status and issue numbers.
    static func subscribers(_ rows: [AdminSubscriber], query: String, status: String?, sort: AdminSort = .newest) -> [AdminSubscriber] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let list = rows.filter { r in
            (status == nil || r.status == status)
                && (q.isEmpty || ([r.email, r.lang ?? "", r.status] + r.issues.map(String.init)).joined(separator: " ").lowercased().contains(q))
        }
        switch sort {
        case .newest: return list.sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
        case .email: return list.sorted { $0.email < $1.email }
        case .lastIssue: return list.sorted { ($0.lastIssue ?? 0) > ($1.lastIssue ?? 0) }
        }
    }

    /// "2026-10-01T01:00:00+00:00" -> "2026-10-01 01:00", as on the web (UTC).
    static func minute(_ iso: String?) -> String {
        String((iso ?? "").prefix(16)).replacingOccurrences(of: "T", with: " ")
    }
}

/// No cookies, no URL cache, no disk: an ephemeral session. Native requests send no Origin header.
struct AdminAPI {
    enum Failure: Error, Equatable {
        case unauthorized(String?), rateLimited, notFound, invalid, unavailable
    }

    var base = AdminConfig.api
    var pressHistoryURL = AdminConfig.pressHistory
    var session: URLSession = AdminAPI.ephemeral

    static let ephemeral: URLSession = URLSession(configuration: configuration())

    static func configuration() -> URLSessionConfiguration {
        let c = URLSessionConfiguration.ephemeral
        c.urlCache = nil
        c.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        c.httpCookieStorage = nil
        c.httpShouldSetCookies = false
        c.timeoutIntervalForRequest = 15
        return c
    }

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    func requestCode(email: String, challenge: String) async throws {
        _ = try await send("login", method: "POST", body: ["email": email, "challenge": challenge])
    }

    func verify(code: String, verifier: String) async throws -> AdminSession {
        try Self.decoder.decode(AdminSession.self, from: send("verify", method: "POST", body: ["code": code, "verifier": verifier]))
    }

    func subscribers(token: String) async throws -> AdminSubscribers {
        try Self.decoder.decode(AdminSubscribers.self, from: send("subscribers", token: token))
    }

    func pressSends(token: String) async throws -> [AdminPressSend] {
        try Self.decoder.decode(AdminPressSends.self, from: send("press-sends", token: token)).sends
    }

    func logout(token: String) async {
        _ = try? await send("logout", method: "POST", token: token)
    }

    /// Public data; never sent with the session token.
    func pressHistory() async throws -> [PressRelease] {
        let (data, response) = try await session.data(from: pressHistoryURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw Failure.notFound }
        return try Self.decoder.decode(PressHistory.self, from: data).releases
    }

    private func send(_ path: String, method: String = "GET", token: String? = nil, body: [String: String]? = nil) async throws -> Data {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = method
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        req.httpShouldHandleCookies = false
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let data: Data, response: URLResponse
        do { (data, response) = try await session.data(for: req) } catch { throw Failure.unavailable }
        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200..<300: return data
        case 400: throw Failure.invalid
        case 401: throw Failure.unauthorized((try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String)
        case 404: throw Failure.notFound
        case 429: throw Failure.rateLimited
        default: throw Failure.unavailable
        }
    }
}

@MainActor
@Observable
final class AdminStore {
    enum Phase: Equatable {
        case signedOut, codeSent(String), signedIn(String)
    }

    private(set) var phase: Phase = .signedOut
    private(set) var subscribers: AdminSubscribers?
    /// nil until loaded, or when the Worker has no press endpoint yet.
    private(set) var pressSends: [AdminPressSend]?
    private(set) var pressReleases: [PressRelease] = []
    private(set) var busy = false
    var message: String?

    private var pkce: AdminPKCE?
    private var session: AdminSession?
    private let api: AdminAPI
    private let keychain: AdminKeychain?

    init(api: AdminAPI = AdminAPI(), keychain: AdminKeychain? = AdminKeychain()) {
        self.api = api
        self.keychain = keychain
        if let s = keychain?.load() {
            if s.isValid { session = s; phase = .signedIn(s.email) } else { keychain?.delete() }
        }
    }

    func requestCode(email raw: String) async {
        guard let email = AdminEmail.normalized(raw) else {
            message = "Use your @\(AdminConfig.domain) address."
            return
        }
        busy = true
        defer { busy = false }
        let p = AdminPKCE()
        do {
            try await api.requestCode(email: email, challenge: p.challenge)
            pkce = p
            phase = .codeSent(email)
            message = "If that address may sign in, a code is on its way. It works once, for 15 minutes."
        } catch AdminAPI.Failure.rateLimited {
            message = "Too many requests. Try again in 10 minutes."
        } catch {
            message = "The admin service is not reachable."
        }
    }

    func verify(code raw: String) async {
        guard let code = AdminCode.normalized(raw), let pkce else {
            message = "Type the 8-digit code from the email."
            return
        }
        busy = true
        defer { busy = false }
        do {
            let s = try await api.verify(code: code, verifier: pkce.verifier)
            self.pkce = nil
            session = s
            keychain?.save(s)
            phase = .signedIn(s.email)
            message = nil
            await load()
        } catch AdminAPI.Failure.unauthorized(let text) {
            message = text ?? "The code is invalid, used or expired. Ask for a new one."
        } catch {
            message = "The admin service is not reachable."
        }
    }

    func startOver() {
        pkce = nil
        phase = .signedOut
        message = nil
    }

    func load() async {
        guard let session, session.isValid else { return endSession("Please sign in again.") }
        do {
            subscribers = try await api.subscribers(token: session.token)
        } catch AdminAPI.Failure.unauthorized {
            return endSession("Please sign in again.")
        } catch {
            message = "Could not load the list."
            return
        }
        message = nil
        pressSends = try? await api.pressSends(token: session.token)
        pressReleases = (try? await api.pressHistory()) ?? []
    }

    func signOut() async {
        if let token = session?.token { await api.logout(token: token) }
        endSession("Signed out.")
    }

    private func endSession(_ text: String) {
        keychain?.delete()
        session = nil
        pkce = nil
        subscribers = nil
        pressSends = nil
        pressReleases = []
        phase = .signedOut
        message = text
    }
}
#endif
