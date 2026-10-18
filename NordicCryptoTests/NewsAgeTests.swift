import XCTest
@testable import Nordic_Crypto

final class NewsAgeTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-10-18T12:00:00+02:00")!

    private func item(_ id: String, _ published: String?) -> String {
        "{\"id\": \"\(id)\", \"title\": \"\(id)\", \"published\": \(published.map { "\"\($0)\"" } ?? "null")}"
    }

    func testOlderThan90DaysOrUndatedIsHidden() throws {
        let json = [
            item("new", "2026-10-17T17:43:46+00:00"),
            item("edge", "2026-07-20T10:30:00+00:00"),
            item("old", "2026-07-20T09:59:59+00:00"),
            item("none", nil),
        ].joined(separator: ",")
        let items = try APIClient.decoder.decode(NewsFeed.self, from: Data("{\"items\": [\(json)]}".utf8)).items
        XCTAssertEqual(NewsItem.recent(items, now: now).map(\.id), ["new", "edge"])
    }
}
