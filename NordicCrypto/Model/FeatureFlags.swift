import Foundation

/// Remote switches set on nordiccrypto.no/admin/ (tip Worker GET /api/flags). Missing or unreachable means off.
@MainActor
@Observable
final class FeatureFlags {
    static let url = URL(string: "https://nordic-crypto-tips.nordiccrypto.workers.dev/api/flags")!

    private(set) var nftIOS = false

    func load(session: URLSession = .shared) async {
        var request = URLRequest(url: Self.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return }
        nftIOS = Self.nftIOS(from: data)
    }

    nonisolated static func nftIOS(from data: Data) -> Bool {
        struct Flags: Decodable {
            struct Platforms: Decodable { var ios: Bool? }
            var nft: Platforms?
        }
        return (try? JSONDecoder().decode(Flags.self, from: data))?.nft?.ios ?? false
    }
}
