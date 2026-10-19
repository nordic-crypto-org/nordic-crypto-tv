import Foundation

enum APIConfig {
    /// Tried in order. The custom domain is the canonical home; GitHub Pages
    /// redirects there once HTTPS is enforced on the Pages site. The raw
    /// gh-pages branch works even while the custom domain is down.
    static let bases: [URL] = [
        // Content Worker: approved stories read live from D1 (60 s cache). Paths it does
        // not serve answer 404, and the next base (the static site) is tried.
        URL(string: "https://api.nordiccrypto.no/api/v1/")!,
        URL(string: "https://nordiccrypto.no/api/v1/")!,
        URL(string: "https://cryptonordic.no/api/v1/")!,
        URL(string: "https://jqrgen.github.io/nordic-crypto/api/v1/")!,
        URL(string: "https://raw.githubusercontent.com/jQrgen/nordic-crypto/gh-pages/api/v1/")!,
    ]
    static let site = URL(string: "https://cryptonordic.no/")!
    static let subscribe = URL(string: "https://cryptonordic.substack.com/subscribe")!
    /// News publisher shown on the Contact us screen.
    static let publisherName = "Nordic Crypto"
    static let publisherCompany = "jQrgenCorp"
    static let publisherOrgNo = "org.nr. 919 057 343"
    static let contactEmail = "jqrgen@nordiccrypto.no"
    static let contactMailto = URL(string: "mailto:jqrgen@nordiccrypto.no")!
    static let website = URL(string: "https://nordiccrypto.no")!
    static let contactPage = URL(string: "https://nordiccrypto.no/contact/")!
    /// The community chat.
    static let telegram = URL(string: "https://t.me/nordiccryptochat")!
    static let telegramHandle = "@nordiccryptochat"
    /// The apps are open source.
    static let sourceCode = URL(string: "https://github.com/nordic-crypto-org/nordic-crypto-tv")!

    /// Files the API links on GitHub Pages, fetched from the gh-pages branch
    /// instead while the Pages site redirects to a domain without HTTPS.
    static func reachable(_ url: URL) -> URL {
        let pages = "https://jqrgen.github.io/nordic-crypto/"
        guard url.absoluteString.hasPrefix(pages) else { return url }
        return URL(string: "https://raw.githubusercontent.com/jQrgen/nordic-crypto/gh-pages/"
                   + url.absoluteString.dropFirst(pages.count)) ?? url
    }
    static let refreshInterval: Duration = .seconds(10 * 60)
    /// The push server (push/ in this repository, docs/push.md).
    static let pushServer = URL(string: "https://nordic-crypto-app-push.nordiccrypto.workers.dev/")!
}

enum APIError: Error {
    case unavailable(String)
}

/// Fetches API documents, keeps the last good copy in Caches, and falls back
/// to the snapshot bundled with the app so the screen is never empty.
struct APIClient {
    var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.requestCachePolicy = .reloadRevalidatingCacheData
        return URLSession(configuration: config)
    }()
    var bundle: Bundle = .main
    /// Where good network copies are kept; nil reads only the bundled snapshot.
    var caches: URL? = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        let plain = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dayOnly = ISO8601DateFormatter()
        dayOnly.formatOptions = [.withFullDate]
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            if let date = plain.date(from: s) ?? fractional.date(from: s) ?? dayOnly.date(from: s) {
                return date
            }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(s)"))
        }
        return d
    }()

    /// Live document from the network, trying each base in turn.
    func fetch<T: Decodable>(_ type: T.Type, path: String) async throws -> T {
        var lastError: Error = APIError.unavailable(path)
        for base in BaseMemory.shared.ordered(APIConfig.bases) {
            do {
                let url = base.appending(path: path)
                let (data, response) = try await session.data(from: url)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw APIError.unavailable("\(url) HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                }
                let value = try Self.decoder.decode(T.self, from: data)
                if let url = cacheURL(path) { try? data.write(to: url, options: .atomic) }
                BaseMemory.shared.remember(base)
                return value
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    /// Last good network copy, or the bundled snapshot.
    func offline<T: Decodable>(_ type: T.Type, path: String) -> T? {
        if let url = cacheURL(path), let data = try? Data(contentsOf: url),
           let value = try? Self.decoder.decode(T.self, from: data) {
            return value
        }
        guard let url = bundle.url(forResource: "Snapshot/" + path, withExtension: nil),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? Self.decoder.decode(T.self, from: data)
    }

    private func cacheURL(_ path: String) -> URL? {
        caches?.appending(path: "api-v1-" + path.replacingOccurrences(of: "/", with: "-"))
    }
}

/// Remembers the base that answered last, so a dead custom domain does not
/// cost a timeout on every refresh. It is still retried after the others fail.
final class BaseMemory: @unchecked Sendable {
    static let shared = BaseMemory()
    private let lock = NSLock()
    private var last: URL?

    func ordered(_ bases: [URL]) -> [URL] {
        lock.withLock {
            guard let last, bases.contains(last) else { return bases }
            return [last] + bases.filter { $0 != last }
        }
    }

    func remember(_ base: URL) {
        lock.withLock { last = base }
    }
}
