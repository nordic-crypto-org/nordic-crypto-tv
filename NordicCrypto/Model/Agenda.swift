import Foundation

/// The TV calendar: upcoming events once each, in date order, in pages that fit the panel.
enum Agenda {
    static let rowsPerPage = 5

    /// Drops ended events (the bundled snapshot and cached copies go stale) and
    /// listings of the same event from several sources, then sorts by start.
    static func upcoming(_ events: [EventItem], now: Date = .now) -> [EventItem] {
        var seen = Set<String>()
        return events
            .filter { !$0.past && ($0.finish.map { $0 > now } ?? false) }
            .sorted { ($0.start!, $0.title) < ($1.start!, $1.title) }
            .filter { seen.insert($0.id).inserted && seen.insert(key($0)).inserted }
    }

    static func pages(_ events: [EventItem]) -> [[EventItem]] {
        stride(from: 0, to: events.count, by: rowsPerPage).map { Array(events[$0..<min($0 + rowsPerPage, events.count)]) }
    }

    /// Same title on the same day is the same event.
    static func key(_ e: EventItem) -> String {
        let title = e.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .filter { $0.isLetter || $0.isNumber }
        return "\(title)|\(e.start.map { day($0, e) } ?? "")"
    }

    /// "Wed 28 Oct · 17:00–19:00" or "Tue 25 Aug – Wed 26 Aug", in the venue's time zone and the app language.
    static func when(_ e: EventItem, lang: String) -> String {
        guard let start = e.start else { return "" }
        let date = style(e, lang).weekday(.abbreviated).day().month(.abbreviated)
        let time = style(e, lang).hour().minute()
        if let end = e.end, day(end, e) != day(start, e) {
            return "\(start.formatted(date)) – \(end.formatted(date))"
        }
        if e.allDay { return start.formatted(date) }
        let span = e.end.map { "\(start.formatted(time))–\($0.formatted(time))" } ?? start.formatted(time)
        return "\(start.formatted(date)) · \(span)"
    }

    /// "Oslo, Norway" or "Online".
    static func place(_ e: EventItem, lang: String) -> String {
        if e.online { return String(localized: "Online", bundle: AppLanguage.bundle) }
        let country = e.country.flatMap { Formats.locale(lang).localizedString(forRegionCode: $0) }
        return [e.city, country].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: ", ")
    }

    static func style(_ e: EventItem, _ lang: String) -> Date.FormatStyle {
        Date.FormatStyle(locale: Formats.locale(lang), timeZone: e.zone)
    }

    static func sameDay(_ a: EventItem, _ b: EventItem) -> Bool {
        guard let x = a.start, let y = b.start else { return false }
        return day(x, a) == day(y, b)
    }

    private static func day(_ date: Date, _ e: EventItem) -> String {
        date.formatted(Date.ISO8601FormatStyle(timeZone: e.zone).year().month().day())
    }
}
