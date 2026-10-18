import XCTest
@testable import Nordic_Crypto

final class SnapshotDecodingTests: XCTestCase {
    /// The bundled snapshot only: the host app's live cache can list a newer
    /// issue whose detail it has not fetched yet.
    private let client = APIClient(bundle: Bundle(for: FeedStore.self), caches: nil)

    func testNewsSnapshotDecodes() throws {
        let feed = try XCTUnwrap(client.offline(NewsFeed.self, path: "news.json"))
        XCTAssertFalse(feed.items.isEmpty)
        XCTAssertTrue(feed.items.allSatisfy { $0.published != nil }, "every story has a parsable date")
        XCTAssertTrue(feed.items.contains { !$0.summaryI18n.isEmpty })
    }

    func testEventsSnapshotDecodes() throws {
        let feed = try XCTUnwrap(client.offline(EventsFeed.self, path: "events.json"))
        XCTAssertFalse(feed.events.isEmpty)
        XCTAssertTrue(feed.events.allSatisfy { $0.start != nil })
    }

    func testNewsletterDetailHasTextAndNewsreel() throws {
        let list = try XCTUnwrap(client.offline(NewslettersFeed.self, path: "newsletters.json"))
        let first = try XCTUnwrap(list.issues.first)
        let detail = try XCTUnwrap(client.offline(NewsletterEnvelope.self, path: "newsletters/\(first.id).json")).item
        XCTAssertNotNil(detail.text(for: "nb"))
        XCTAssertNotNil(detail.video?.playableURL)
    }

    func testLanguageResolution() {
        XCTAssertEqual(AppLanguage.resolve(["nb-NO"]), "nn")
        XCTAssertEqual(AppLanguage.resolve(["no"]), "nn")
        XCTAssertEqual(AppLanguage.resolve(["nn-NO"]), "nn")
        XCTAssertEqual(AppLanguage.resolve(["en-GB"], region: "NO"), "nn")
        XCTAssertEqual(AppLanguage.resolve(["sv-SE"], region: "NO"), "sv")
        XCTAssertEqual(AppLanguage.resolve(["en-GB"], region: "GB"), "en")
        XCTAssertEqual(AppLanguage.resolve(["sv-SE", "en"]), "sv")
        XCTAssertEqual(AppLanguage.resolve(["ko-KR", "da"]), "da")
        XCTAssertEqual(AppLanguage.resolve(["de-DE"]), "de")
        XCTAssertEqual(AppLanguage.resolve(["zh-Hans-CN"]), "zh")
        XCTAssertEqual(AppLanguage.resolve(["it-IT"]), "en")
    }

    func testNynorskFallsBackToBokmal() throws {
        let json = """
        {"id": "a", "title": "Bokmål", "title_en": "English", "language_code": "no",
         "title_i18n": {"nn": "Nynorsk"}, "summary": "Summary", "summary_i18n": {"nb": "Sammendrag"}}
        """
        let item = try JSONDecoder().decode(NewsItem.self, from: Data(json.utf8))
        XCTAssertEqual(item.headline(for: "nn"), "Nynorsk")
        XCTAssertNil(item.originalHeadline(for: "nn"))
        XCTAssertEqual(item.headline(for: "nb"), "Bokmål")
        XCTAssertEqual(item.summary(for: "nn"), "Sammendrag")
        XCTAssertEqual(item.summary(for: "sv"), "Summary")
        XCTAssertEqual(["nb": "Nett"].localized("nn"), "Nett")
    }

    func testNynorskCatalogue() throws {
        let nn = try XCTUnwrap(Bundle.main.path(forResource: "nn", ofType: "lproj").flatMap(Bundle.init(path:)))
        XCTAssertEqual(String(localized: "Norway", bundle: nn), "Noreg")
    }

    func testNorwegianReaderSeesOriginalNorwegianHeadline() throws {
        let feed = try XCTUnwrap(client.offline(NewsFeed.self, path: "news.json"))
        let norwegian = try XCTUnwrap(feed.items.first { $0.languageCode == "no" && $0.titleEn != nil })
        XCTAssertEqual(norwegian.headline(for: "nb"), norwegian.title)
        XCTAssertEqual(norwegian.headline(for: "en"), norwegian.titleEn)
        XCTAssertEqual(norwegian.originalHeadline(for: "en"), norwegian.title)
    }
}
