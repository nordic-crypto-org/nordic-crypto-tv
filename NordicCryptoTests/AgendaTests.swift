import XCTest
@testable import Nordic_Crypto

final class AgendaTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-10-18T06:00:00+02:00")!

    private func events(_ json: String) throws -> [EventItem] {
        try APIClient.decoder.decode(EventsFeed.self, from: Data("{\"events\": [\(json)]}".utf8)).events
    }

    private func event(_ id: String, _ title: String, _ start: String, _ end: String? = nil,
                       city: String = "Oslo", country: String = "NO", past: Bool = false) -> String {
        """
        {"id": "\(id)", "title": "\(title)", "start": "\(start)", "end": \(end.map { "\"\($0)\"" } ?? "null"),
         "city": "\(city)", "country": "\(country)", "past": \(past)}
        """
    }

    func testSortedByStartPastRemovedAndDeduped() throws {
        let list = try events([
            event("c", "Late", "2027-02-05T18:00:00+02:00"),
            event("a", "Stale", "2026-10-15T17:30:00+02:00", "2026-10-15T20:30:00+02:00"),
            event("p", "Flagged", "2026-10-30T18:00:00+01:00", past: true),
            event("b", "Uppsala Bitcoin Meetup", "2026-11-13T18:00:00+01:00"),
            event("b2", "Uppsala bitcoin meetup ", "2026-11-13T18:30:00+01:00"),
            event("b3", "Uppsala Bitcoin Meetup", "2026-12-11T18:00:00+01:00"),
            event("o", "Ongoing", "2026-10-17T09:00:00+02:00", "2026-10-19T17:00:00+02:00"),
            event("c", "Late", "2027-02-05T18:00:00+02:00"),
        ].joined(separator: ","))
        XCTAssertEqual(Agenda.upcoming(list, now: now).map(\.id), ["o", "b", "b3", "c"])
    }

    func testEventWithoutEndStaysUntilItIsOver() throws {
        let list = try events(event("x", "Talk", "2026-10-18T05:00:00+02:00"))
        XCTAssertEqual(Agenda.upcoming(list, now: now).count, 1)
        XCTAssertTrue(Agenda.upcoming(list, now: now.addingTimeInterval(3 * 3_600)).isEmpty)
    }

    func testPagesFitTheRows() throws {
        let list = try events((0..<12).map { event("\($0)", "E\($0)", "2026-11-\(10 + $0)T18:00:00+01:00") }.joined(separator: ","))
        let pages = Agenda.pages(Agenda.upcoming(list, now: now))
        XCTAssertEqual(pages.map(\.count), [5, 5, 2])
        XCTAssertEqual(pages.flatMap { $0 }.map(\.id), (0..<12).map(String.init), "pages keep date order, no wrap-around")
    }

    func testDatesInTheVenueTimeZoneAndAppLanguage() throws {
        let list = try events([
            event("h", "Helsinki", "2026-11-06T18:00:00+02:00", "2026-11-06T21:00:00+02:00", city: "Helsinki", country: "FI"),
            event("l", "Lund", "2026-08-25T08:30:00+02:00", "2026-08-26T12:30:00+02:00", city: "Lund", country: "SE"),
            event("d", "Day", "2026-11-20"),
        ].joined(separator: ","))
        XCTAssertEqual(Agenda.when(list[0], lang: "en"), "Fri 6 Nov · 18:00–21:00")
        XCTAssertEqual(Agenda.when(list[1], lang: "en"), "Tue 25 Aug – Wed 26 Aug")
        XCTAssertEqual(Agenda.when(list[2], lang: "en"), "Fri 20 Nov")
        XCTAssertTrue(list[2].allDay)
        XCTAssertEqual(Agenda.place(list[0], lang: "en"), "Helsinki, Finland")
        XCTAssertEqual(Agenda.place(list[0], lang: "sv"), "Helsinki, Finland")
        XCTAssertEqual(Agenda.place(list[1], lang: "nb"), "Lund, Sverige")
        XCTAssertTrue(Agenda.when(list[0], lang: "nb").contains("18:00–21:00"))
    }
}
