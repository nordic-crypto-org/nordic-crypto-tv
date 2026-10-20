import Foundation

/// Remote switches from api/v1/flags.json on the site. Missing or unreachable means off.
@MainActor
@Observable
final class FeatureFlags {
    static let url = URL(string: "https://nordiccrypto.no/api/v1/flags.json")!

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
