import Foundation
import Observation

@MainActor
@Observable
final class FeedStore {
    enum Status: Equatable {
        case live(Date)
        case offline
        case loading
    }

    private(set) var news: [NewsItem] = []
    private(set) var events: [EventItem] = []
    private(set) var issues: [NewsletterIssue] = []
    private(set) var issueDetails: [String: NewsletterIssue] = [:]
    /// Approved outlet logos by source id.
    private(set) var sourceLogos: [String: URL] = [:]
    /// Who's who and academia, shuffled once per launch for the TV spotlight.
    private(set) var spotlight: [SpotlightItem] = []
    private(set) var entities: [String: OrgEntity] = [:]
    private var orgChart: [OrgEntity] = []
    private var academia: [AcademiaItem] = []
    private(set) var updated: Date?
    private(set) var status: Status = .loading

    let lang = AppLanguage.current
    private let client: APIClient

    init(client: APIClient = APIClient()) {
        self.client = client
        loadOffline()
        if SnapshotMode.isOn {
            status = .live(SnapshotMode.frozenDate)
        }
    }

    var upcomingEvents: [EventItem] {
        Agenda.upcoming(events)
    }

    var pastEvents: [EventItem] {
        events.filter(\.past).sorted { ($0.start ?? .distantPast) > ($1.start ?? .distantPast) }
    }

    /// The three newest stories: one lead and two secondary.
    var topStories: [NewsItem] { Array(news.prefix(3)) }

    /// Everything after the top stories, newest day first. No story repeats.
    var moreNewsByDay: [(day: Date, items: [NewsItem])] {
        let cal = Calendar.current
        var groups: [(day: Date, items: [NewsItem])] = []
        for item in news.dropFirst(3) {
            let day = cal.startOfDay(for: item.published ?? .distantPast)
            if groups.last?.day == day {
                groups[groups.count - 1].items.append(item)
            } else {
                groups.append((day: day, items: [item]))
            }
        }
        return groups
    }

    func news(in country: Country) -> [NewsItem] {
        news.filter { $0.country == country.rawValue }
    }

    /// The most common topics, for the "most read topics" board.
    var topTopics: [(topic: String, count: Int)] {
        var counts: [String: Int] = [:]
        for item in news { for t in item.topics { counts[t, default: 0] += 1 } }
        return counts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { (topic: $0.key, count: $0.value) }
    }

    func issue(_ id: String) -> NewsletterIssue? { issueDetails[id] }

    func logo(for item: NewsItem) -> URL? {
        item.sourceLogoURL ?? item.source.flatMap { sourceLogos[$0] }
    }

    private func loadOffline() {
        if let feed = client.offline(NewsFeed.self, path: "news.json") { apply(feed) }
        if let feed = client.offline(EventsFeed.self, path: "events.json") { events = feed.events }
        if let feed = client.offline(NewslettersFeed.self, path: "newsletters.json") { applyIssues(feed.issues) }
        if let feed = client.offline(SourcesFeed.self, path: "sources.json") { applySources(feed) }
        if let feed = client.offline(OrgChartFeed.self, path: "orgchart.json") { orgChart = feed.entities }
        if let feed = client.offline(AcademiaFeed.self, path: "academia.json") { academia = feed.all }
        rebuildSpotlight()
        for issue in issues {
            if let detail = client.offline(NewsletterEnvelope.self, path: "newsletters/\(issue.id).json") {
                issueDetails[issue.id] = detail.item
            }
        }
    }

    /// Refreshes everything, then repeats every `APIConfig.refreshInterval`.
    /// `-NCSnapshot` stays on the bundled fixture so screenshots do not change.
    func run() async {
        if SnapshotMode.isOn { return }
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: APIConfig.refreshInterval)
        }
    }

    func refresh() async {
        do {
            async let newsFeed = client.fetch(NewsFeed.self, path: "news.json")
            async let eventsFeed = client.fetch(EventsFeed.self, path: "events.json")
            async let issuesFeed = client.fetch(NewslettersFeed.self, path: "newsletters.json")
            let (n, e, i) = try await (newsFeed, eventsFeed, issuesFeed)
            apply(n)
            #if os(iOS) || os(macOS) || os(visionOS)
            NewsAlerts.shared.process(n.items, lang: lang)
            #endif
            events = e.events
            applyIssues(i.issues)
            status = .live(.now)
            if let sources = try? await client.fetch(SourcesFeed.self, path: "sources.json") { applySources(sources) }
            #if os(tvOS)
            if let feed = try? await client.fetch(OrgChartFeed.self, path: "orgchart.json") { orgChart = feed.entities }
            if let feed = try? await client.fetch(AcademiaFeed.self, path: "academia.json") { academia = feed.all }
            rebuildSpotlight()
            #endif
            for issue in issues where issueDetails[issue.id]?.text == nil || issue.id == issues.first?.id {
                if let detail = try? await client.fetch(NewsletterEnvelope.self, path: "newsletters/\(issue.id).json") {
                    issueDetails[issue.id] = detail.item
                }
            }
        } catch {
            status = .offline
        }
    }

    private func apply(_ feed: NewsFeed) {
        news = NewsItem.recent(feed.items).sorted { ($0.published ?? .distantPast) > ($1.published ?? .distantPast) }
        updated = feed.updated ?? feed.generatedAt
    }

    /// Mixes people, companies, public bodies and academia into one random
    /// order, keeping the current order for items that were already there.
    private func rebuildSpotlight() {
        entities = Dictionary(orgChart.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let fresh = orgChart.map(SpotlightItem.entity) + academia.map(SpotlightItem.academia)
        if SnapshotMode.isOn {
            spotlight = fresh.sorted { $0.id < $1.id }
            return
        }
        let known = Set(spotlight.map(\.id))
        let kept = spotlight.filter { item in fresh.contains { $0.id == item.id } }
        spotlight = kept + fresh.filter { !known.contains($0.id) }.shuffled()
        if kept.isEmpty { spotlight.shuffle() }
    }

    private func applySources(_ feed: SourcesFeed) {
        sourceLogos = Dictionary(feed.sources.compactMap { s in s.logoURL.map { (s.id, $0) } },
                                 uniquingKeysWith: { first, _ in first })
    }

    private func applyIssues(_ list: [NewsletterIssue]) {
        issues = list.sorted { ($0.number ?? 0) > ($1.number ?? 0) }
    }
}
