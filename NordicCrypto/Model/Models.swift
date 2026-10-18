import Foundation

// Types for the Nordic Crypto data API, version 1 (/api/v1/).
// The API promises that v1 field names stay but new fields may appear, so
// everything except ids and titles is optional and unknown keys are ignored.

struct NewsFeed: Decodable {
    var generatedAt: Date?
    var updated: Date?
    var items: [NewsItem]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at", updated, items
    }
}

struct NewsItem: Decodable, Identifiable, Hashable {
    var id: String
    var url: URL?
    var title: String
    var titleEn: String?
    var source: String?
    var sourceName: String?
    /// The outlet's logo, once the editors have approved it.
    var sourceLogoURL: URL?
    var country: String?
    var language: String?
    var languageCode: String?
    var published: Date?
    var topics: [String]
    var summary: String?
    var summaryI18n: [String: String]
    var titleI18n: [String: String]
    var paywall: Bool
    var ownStory: Bool

    enum CodingKeys: String, CodingKey {
        case id, url, title, country, language, published, topics, summary, paywall
        case source
        case titleEn = "title_en", sourceName = "source_name", languageCode = "language_code"
        case sourceLogoURL = "source_logo_url"
        case summaryI18n = "summary_i18n", ownStory = "own_story"
        case titleI18n = "title_i18n"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        url = try? c.decodeIfPresent(URL.self, forKey: .url)
        titleEn = try c.decodeIfPresent(String.self, forKey: .titleEn)
        source = try? c.decodeIfPresent(String.self, forKey: .source)
        sourceName = try c.decodeIfPresent(String.self, forKey: .sourceName)
        sourceLogoURL = try? c.decodeIfPresent(URL.self, forKey: .sourceLogoURL)
        country = try c.decodeIfPresent(String.self, forKey: .country)
        language = try c.decodeIfPresent(String.self, forKey: .language)
        languageCode = try c.decodeIfPresent(String.self, forKey: .languageCode)
        published = try? c.decodeIfPresent(Date.self, forKey: .published)
        topics = (try? c.decodeIfPresent([String].self, forKey: .topics)) ?? []
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
        summaryI18n = (try? c.decodeIfPresent([String: String].self, forKey: .summaryI18n)) ?? [:]
        titleI18n = (try? c.decodeIfPresent([String: String].self, forKey: .titleI18n)) ?? [:]
        paywall = (try? c.decodeIfPresent(Bool.self, forKey: .paywall)) ?? false
        ownStory = (try? c.decodeIfPresent(Bool.self, forKey: .ownStory)) ?? false
    }

    /// Headline in the reader's language when we have one, else the original.
    func headline(for lang: String) -> String {
        for l in AppLanguage.fallbacks(lang) {
            if languageCode == l || (l == "nb" && languageCode == "no") { return title }
            if let t = titleI18n[l] { return t }
        }
        if languageCode.map({ AppLanguage.sameFamily($0, lang) }) == true { return title }
        return titleEn ?? title
    }

    /// The original-language headline, when it differs from `headline(for:)`
    /// (not the bokmål original under a nynorsk headline).
    func originalHeadline(for lang: String) -> String? {
        let shown = headline(for: lang)
        if shown == title || languageCode.map({ AppLanguage.sameFamily($0, lang) }) == true { return nil }
        return title
    }

    func summary(for lang: String) -> String? {
        summaryI18n.localized(lang) ?? summary
    }
}

struct SourcesFeed: Decodable {
    var sources: [Source]

    struct Source: Decodable {
        var id: String
        var name: String?
        var logoURL: URL?

        enum CodingKeys: String, CodingKey {
            case id, name
            case logoURL = "logo_url"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            name = try? c.decodeIfPresent(String.self, forKey: .name)
            logoURL = try? c.decodeIfPresent(URL.self, forKey: .logoURL)
        }
    }
}

struct EventsFeed: Decodable {
    var events: [EventItem]
}

struct EventItem: Decodable, Identifiable, Hashable {
    var id: String
    var title: String
    var titleOriginal: String?
    var start: Date?
    var end: Date?
    var place: String?
    var city: String?
    var country: String?
    var online: Bool
    var organiser: String?
    var url: URL?
    var paid: Bool?
    var sponsored: String?
    var note: String?
    var noteI18n: [String: String]
    var past: Bool
    /// People signed up (Meetup RSVPs), when the API knows.
    var going: Int?
    /// Where the listing came from ("Litteraturhuset Oslo").
    var source: String?
    var description: EventDescription?
    /// Where the venue was looked up, and when.
    var placeSource: EventSource?
    /// The event's page on nordiccrypto.no, per language.
    var htmlURL: URL?
    var htmlURLs: [String: URL]
    var ongoing: Bool
    /// The venue's UTC offset from the feed; a date without a time is a whole day.
    var zone: TimeZone = .current
    var allDay = false

    enum CodingKeys: String, CodingKey {
        case id, title, start, end, place, city, country, online, organiser, url, paid, sponsored, note, past
        case going, source, description, ongoing
        case titleOriginal = "title_original", noteI18n = "note_i18n"
        case placeSource = "place_source", htmlURL = "html_url", htmlURLs = "html_urls"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        titleOriginal = try c.decodeIfPresent(String.self, forKey: .titleOriginal)
        start = try? c.decodeIfPresent(Date.self, forKey: .start)
        if let raw = try? c.decodeIfPresent(String.self, forKey: .start) {
            allDay = !raw.contains("T")
            zone = allDay ? .gmt : Self.offset(raw) ?? .current
        }
        end = try? c.decodeIfPresent(Date.self, forKey: .end)
        place = try c.decodeIfPresent(String.self, forKey: .place)
        city = try c.decodeIfPresent(String.self, forKey: .city)
        country = try c.decodeIfPresent(String.self, forKey: .country)
        online = (try? c.decodeIfPresent(Bool.self, forKey: .online)) ?? false
        organiser = try c.decodeIfPresent(String.self, forKey: .organiser)
        url = try? c.decodeIfPresent(URL.self, forKey: .url)
        paid = try? c.decodeIfPresent(Bool.self, forKey: .paid)
        // `sponsored` is a sponsor name or null; tolerate a bool as well.
        if let name = try? c.decodeIfPresent(String.self, forKey: .sponsored) {
            sponsored = name
        } else if (try? c.decodeIfPresent(Bool.self, forKey: .sponsored)) == true {
            sponsored = ""
        }
        note = try c.decodeIfPresent(String.self, forKey: .note)
        noteI18n = (try? c.decodeIfPresent([String: String].self, forKey: .noteI18n)) ?? [:]
        past = (try? c.decodeIfPresent(Bool.self, forKey: .past)) ?? false
        going = try? c.decodeIfPresent(Int.self, forKey: .going)
        source = try? c.decodeIfPresent(String.self, forKey: .source)
        description = try? c.decodeIfPresent(EventDescription.self, forKey: .description)
        placeSource = try? c.decodeIfPresent(EventSource.self, forKey: .placeSource)
        htmlURL = try? c.decodeIfPresent(URL.self, forKey: .htmlURL)
        htmlURLs = (try? c.decodeIfPresent([String: URL].self, forKey: .htmlURLs)) ?? [:]
        ongoing = (try? c.decodeIfPresent(Bool.self, forKey: .ongoing)) ?? false
    }

    func note(for lang: String) -> String? {
        noteI18n.localized(lang) ?? note
    }

    /// The organiser's own title when it is in the reader's language.
    func title(for lang: String) -> String {
        guard let titleOriginal, let source = description?.lang, AppLanguage.sameFamily(source, lang) else { return title }
        return titleOriginal
    }

    /// When the event is over; without an end, a whole day or three hours.
    var finish: Date? {
        guard let start else { return nil }
        return end ?? start.addingTimeInterval(allDay ? 86_400 : 3 * 3_600)
    }

    /// "+01:00" or "Z" at the end of an ISO 8601 time.
    static func offset(_ raw: String) -> TimeZone? {
        if raw.hasSuffix("Z") { return .gmt }
        let tail = raw.suffix(6)
        guard tail.count == 6, let sign = tail.first, sign == "+" || sign == "-",
              let h = Int(tail.dropFirst().prefix(2)), let m = Int(tail.suffix(2)) else { return nil }
        return TimeZone(secondsFromGMT: (sign == "-" ? -1 : 1) * (h * 3_600 + m * 60))
    }

    /// The event's page on nordiccrypto.no in the reader's language.
    func page(for lang: String) -> URL? {
        htmlURLs[lang] ?? htmlURL
    }

    /// Venue, city and country in one line, as the website shows it.
    func location(lang: String) -> String? {
        if online { return String(localized: "Online", bundle: AppLanguage.bundle) }
        let countryName = country.flatMap { Formats.locale(lang).localizedString(forRegionCode: $0) }
        var parts = [place, city, countryName].compactMap { $0?.isEmpty == false ? $0 : nil }
        // Skip the city when the venue already names it.
        if let place, let city, place.localizedCaseInsensitiveContains(city) {
            parts.removeAll { $0 == city }
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// Apple Maps search for the venue.
    func mapURL(lang: String) -> URL? {
        guard !online, let query = location(lang: lang) else { return nil }
        var c = URLComponents(string: "https://maps.apple.com/")!
        c.queryItems = [URLQueryItem(name: "q", value: query)]
        return c.url
    }
}

/// "About this event": the organiser's text, with translations.
struct EventDescription: Decodable, Hashable {
    var text: String
    /// Language of `text`.
    var lang: String?
    var sourceURL: URL?
    var sourceName: String?
    var retrieved: Date?
    var i18n: [String: String]

    enum CodingKeys: String, CodingKey {
        case text, lang, retrieved, i18n
        case sourceURL = "source_url", sourceName = "source_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decode(String.self, forKey: .text)
        lang = try? c.decodeIfPresent(String.self, forKey: .lang)
        sourceURL = try? c.decodeIfPresent(URL.self, forKey: .sourceURL)
        sourceName = try? c.decodeIfPresent(String.self, forKey: .sourceName)
        retrieved = try? c.decodeIfPresent(Date.self, forKey: .retrieved)
        i18n = (try? c.decodeIfPresent([String: String].self, forKey: .i18n)) ?? [:]
    }

    /// The text in the reader's language, else the original.
    func text(for reader: String) -> String {
        for l in AppLanguage.fallbacks(reader) {
            if l == lang || (l == "nb" && lang == "no") { return text }
            if let t = i18n[l] { return t }
        }
        return text
    }

    /// The original, when it differs from what `text(for:)` shows.
    func original(for reader: String) -> String? {
        text(for: reader) == text ? nil : text
    }
}

struct EventSource: Decodable, Hashable {
    var name: String?
    var url: URL?
    var retrieved: Date?
}

struct NewslettersFeed: Decodable {
    var issues: [NewsletterIssue]
}

struct NewsletterEnvelope: Decodable {
    var item: NewsletterIssue
}

struct NewsletterIssue: Decodable, Identifiable, Hashable {
    var id: String
    var number: Int?
    var date: String?
    var title: String
    var subtitle: String?
    var titleI18n: [String: String]
    var subtitleI18n: [String: String]
    var stories: Int?
    var events: Int?
    var signOff: String?
    var htmlURL: URL?
    var apiURL: URL?
    /// Only present on the single-issue endpoint (`newsletters/{id}.json`).
    var text: String?
    var textI18n: [String: String]
    var video: Newsreel?

    enum CodingKeys: String, CodingKey {
        case id, number, date, title, subtitle, stories, events, text, video
        case titleI18n = "title_i18n", subtitleI18n = "subtitle_i18n", signOff = "sign_off"
        case htmlURL = "html_url", apiURL = "api_url", textI18n = "text_i18n"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        number = try? c.decodeIfPresent(Int.self, forKey: .number)
        date = try? c.decodeIfPresent(String.self, forKey: .date)
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle)
        titleI18n = (try? c.decodeIfPresent([String: String].self, forKey: .titleI18n)) ?? [:]
        subtitleI18n = (try? c.decodeIfPresent([String: String].self, forKey: .subtitleI18n)) ?? [:]
        // `stories`/`events` are counts in the list and may be arrays in the detail.
        stories = try? c.decodeIfPresent(Int.self, forKey: .stories)
        events = try? c.decodeIfPresent(Int.self, forKey: .events)
        signOff = try c.decodeIfPresent(String.self, forKey: .signOff)
        htmlURL = try? c.decodeIfPresent(URL.self, forKey: .htmlURL)
        apiURL = try? c.decodeIfPresent(URL.self, forKey: .apiURL)
        text = try c.decodeIfPresent(String.self, forKey: .text)
        textI18n = (try? c.decodeIfPresent([String: String].self, forKey: .textI18n)) ?? [:]
        video = try? c.decodeIfPresent(Newsreel.self, forKey: .video)
    }

    func title(for lang: String) -> String { titleI18n.localized(lang) ?? title }
    func subtitle(for lang: String) -> String? { subtitleI18n.localized(lang) ?? subtitle }
    func text(for lang: String) -> String? { textI18n.localized(lang) ?? text }
}

struct Newsreel: Decodable, Hashable {
    var durationSeconds: Int?
    var downloadURL: URL?
    var fileURL: URL?
    var posterURL: URL?

    enum CodingKeys: String, CodingKey {
        case durationSeconds = "duration_seconds", downloadURL = "download_url"
        case fileURL = "file_url", posterURL = "poster_url"
    }

    /// The GitHub release asset is served over HTTPS today, so try it first.
    var playableURL: URL? { downloadURL ?? fileURL }
}

enum Country: String, CaseIterable, Identifiable {
    case no = "NO", se = "SE", dk = "DK", fi = "FI", `is` = "IS"
    var id: String { rawValue }

    var name: String {
        switch self {
        case .no: String(localized: "Norway", bundle: AppLanguage.bundle)
        case .se: String(localized: "Sweden", bundle: AppLanguage.bundle)
        case .dk: String(localized: "Denmark", bundle: AppLanguage.bundle)
        case .fi: String(localized: "Finland", bundle: AppLanguage.bundle)
        case .is: String(localized: "Iceland", bundle: AppLanguage.bundle)
        }
    }

    var capitalName: String {
        switch self {
        case .no: "Oslo"
        case .se: "Stockholm"
        case .dk: "København"
        case .fi: "Helsinki"
        case .is: "Reykjavík"
        }
    }

    var timeZone: TimeZone {
        switch self {
        case .no: TimeZone(identifier: "Europe/Oslo")!
        case .se: TimeZone(identifier: "Europe/Stockholm")!
        case .dk: TimeZone(identifier: "Europe/Copenhagen")!
        case .fi: TimeZone(identifier: "Europe/Helsinki")!
        case .is: TimeZone(identifier: "Atlantic/Reykjavik")!
        }
    }
}

enum AppLanguage {
    /// Languages the API translates our own text (summaries, notes) into.
    static let supported = ["nb", "nn", "sv", "da", "fi", "is"]

    /// Interface languages beyond the Nordic set (Nordic Crypto API language list).
    /// Summaries stay in English for these.
    static let interfaceOnly = ["zh", "hi", "es", "fr", "ar", "bn", "pt", "ru", "ur", "id", "de", "ja", "sw", "mr"]

    /// The best language for this device: a Nordic code, one of `interfaceOnly`, or en.
    static var current: String { resolve(Locale.preferredLanguages, region: Locale.current.region?.identifier) }

    /// Norwegian (no, nb, nn) reads nynorsk, as does English in Norway.
    static func resolve(_ preferred: [String], region: String? = nil) -> String {
        var found = "en"
        for tag in preferred {
            let code = Locale(identifier: tag).language.languageCode?.identifier ?? tag
            if ["no", "nb", "nn"].contains(code) { return "nn" }
            if supported.contains(code) || interfaceOnly.contains(code) || code == "en" { found = code; break }
        }
        return found == "en" && region == "NO" ? "nn" : found
    }

    /// Where to look for a translation, best first: nynorsk falls back to bokmål.
    static func fallbacks(_ lang: String) -> [String] {
        lang == "nn" ? ["nn", "nb"] : [lang]
    }

    /// The app's string catalogue in `current`, for `String(localized:bundle:)`
    /// when that differs from the system's pick (nynorsk on a bokmål Apple TV).
    static let bundle: Bundle = current == "nn" ? Bundle.main.path(forResource: "nn", ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main : .main

    /// Norwegian sources are tagged "no"; treat nb and nn as the same family.
    static func sameFamily(_ a: String, _ b: String) -> Bool {
        let norsk: Set<String> = ["no", "nb", "nn"]
        return a == b || (norsk.contains(a) && norsk.contains(b))
    }
}

extension Dictionary where Key == String, Value == String {
    /// The translation for `lang`, following `AppLanguage.fallbacks`.
    func localized(_ lang: String) -> String? {
        AppLanguage.fallbacks(lang).lazy.compactMap { self[$0] }.first
    }
}
