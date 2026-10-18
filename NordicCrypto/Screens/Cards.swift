import SwiftUI

// Cards shared by Today, Countries and Events. Every card is one button and one
// VoiceOver element.

struct LeadCard: View {
    let item: NewsItem
    var height: CGFloat
    var summaryLines: Int
    var animated = false
    @Environment(FeedStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        Button { router.open(.story(item)) } label: {
            ZStack(alignment: .bottomLeading) {
                AuroraArt(story: item, animated: animated)
                VStack(alignment: .leading, spacing: 12) {
                    Kicker(item: item, lang: store.lang)
                    Text(item.headline(for: store.lang))
                        .font(NLFont.display)
                        .foregroundStyle(NL.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                    if let original = item.originalHeadline(for: store.lang) {
                        Text(original)
                            .font(NLFont.body).italic()
                            .foregroundStyle(NL.textSecondary)
                            .lineLimit(1)
                    }
                    if summaryLines > 0, let summary = item.summary(for: store.lang) {
                        Text(summary)
                            .font(NLFont.body)
                            .foregroundStyle(NL.textSecondary)
                            .lineLimit(summaryLines)
                            .multilineTextAlignment(.leading)
                    }
                    HStack(spacing: 8) {
                        ForEach(item.topics.prefix(3), id: \.self) { TopicChip(topic: $0) }
                    }
                }
                .padding(NLMetrics.cardPadding)
            }
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .clipShape(RoundedRectangle(cornerRadius: NLMetrics.cardRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: NLMetrics.cardRadius, style: .continuous))
        }
        .nlCardButton()
        .accessibilityElement(children: .combine)
    }
}

struct SecondaryCard: View {
    let item: NewsItem
    var height: CGFloat
    @Environment(FeedStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        Button { router.open(.story(item)) } label: {
            ZStack(alignment: .bottomLeading) {
                AuroraArt(story: item)
                VStack(alignment: .leading, spacing: 10) {
                    Kicker(item: item, lang: store.lang)
                    Text(item.headline(for: store.lang))
                        .font(NLFont.title)
                        .foregroundStyle(NL.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    if let topic = item.topics.first { TopicChip(topic: topic) }
                }
                .padding(NLMetrics.cardPadding)
            }
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .clipShape(RoundedRectangle(cornerRadius: NLMetrics.cardRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: NLMetrics.cardRadius, style: .continuous))
        }
        .nlCardButton()
        .accessibilityElement(children: .combine)
    }
}

/// iPhone: art thumbnail on the left, text on the right.
struct CompactStoryCard: View {
    let item: NewsItem
    @Environment(FeedStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        Button { router.open(.story(item)) } label: {
            HStack(spacing: 14) {
                AuroraArt(story: item, scrim: false)
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    Kicker(item: item, lang: store.lang)
                    Text(item.headline(for: store.lang))
                        .font(NLFont.row)
                        .foregroundStyle(NL.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .nlGlass(cornerRadius: NLMetrics.rowRadius)
            .contentShape(Rectangle())
        }
        .nlCardButton()
        .accessibilityElement(children: .combine)
    }
}

/// A glass row with the country's color along the leading edge.
struct NewsRow: View {
    let item: NewsItem
    var lines = 2
    @Environment(FeedStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        Button { router.open(.story(item)) } label: {
            HStack(spacing: 0) {
                Rectangle().fill(NL.country(item.country)).frame(width: 4)
                VStack(alignment: .leading, spacing: 8) {
                    Kicker(item: item, lang: store.lang)
                    Text(item.headline(for: store.lang))
                        .font(NLFont.row)
                        .foregroundStyle(NL.textPrimary)
                        .lineLimit(lines)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(NLMetrics.cardPadding * 0.75)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .nlGlass(cornerRadius: NLMetrics.rowRadius)
            .clipShape(RoundedRectangle(cornerRadius: NLMetrics.rowRadius, style: .continuous))
            .contentShape(Rectangle())
        }
        .nlCardButton()
        .accessibilityElement(children: .combine)
    }
}

struct EventMiniCard: View {
    let event: EventItem
    @Environment(FeedStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        Button { router.open(.event(event)) } label: {
            HStack(alignment: .top, spacing: 14) {
                DateTile(date: event.start, country: event.country, lang: store.lang)
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.title)
                        .font(NLFont.row)
                        .foregroundStyle(NL.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(verbatim: [event.online ? String(localized: "Online", bundle: AppLanguage.bundle) : event.city, Formats.time(event.start, lang: store.lang)]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(NLFont.caption)
                        .foregroundStyle(NL.textSecondary)
                    EntryBadge(event: event)
                }
                Spacer(minLength: 0)
            }
            .padding(NLMetrics.cardPadding * 0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .nlGlass(cornerRadius: NLMetrics.rowRadius)
            .contentShape(Rectangle())
        }
        .nlCardButton()
        .accessibilityElement(children: .combine)
    }
}

struct NewsletterCard: View {
    let issue: NewsletterIssue
    var height: CGFloat
    @Environment(FeedStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        Button { router.tab = .newsletter } label: {
            ZStack(alignment: .bottomLeading) {
                AuroraArt.newsletter(seed: issue.id)
                VStack(alignment: .leading, spacing: 10) {
                    Text(verbatim: "No. \(issue.number ?? 0) · \(issue.date.flatMap(Self.parse).map { Formats.day($0, lang: store.lang) } ?? "")")
                        .font(NLFont.kicker)
                        .foregroundStyle(NL.accent2)
                    Text(issue.title(for: store.lang))
                        .font(NLFont.title)
                        .foregroundStyle(NL.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 14) {
                        if let n = issue.stories { Text("\(n) stories") }
                        if let n = issue.events { Text("\(n) events") }
                        if let d = store.issue(issue.id)?.video?.durationSeconds {
                            Label(Formats.duration(d), systemImage: "play.fill")
                        }
                    }
                    .font(NLFont.caption.weight(.semibold))
                    .foregroundStyle(NL.textSecondary)
                }
                .padding(NLMetrics.cardPadding)
            }
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .clipShape(RoundedRectangle(cornerRadius: NLMetrics.cardRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: NLMetrics.cardRadius, style: .continuous))
        }
        .nlCardButton()
        .accessibilityElement(children: .combine)
    }

    static func parse(_ day: String) -> Date? {
        try? Date(day, strategy: .iso8601.year().month().day())
    }
}

struct CountryTile: View {
    let country: Country
    var height: CGFloat
    @Environment(FeedStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        let items = store.news(in: country)
        Button { router.open(.country(country.rawValue)) } label: {
            ZStack(alignment: .bottomLeading) {
                AuroraArt(country: country.rawValue)
                    .opacity(items.isEmpty ? 0.45 : 1)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        CountryChip(code: country.rawValue)
                        Spacer()
                        Text(items.count, format: .number)
                            .font(NLFont.dateDay)
                            .foregroundStyle(items.isEmpty ? NL.textTertiary : NL.textPrimary)
                    }
                    Text(country.name)
                        .font(NLFont.title)
                        .foregroundStyle(NL.textPrimary)
                    if let top = items.first {
                        Text(top.headline(for: store.lang))
                            .font(NLFont.caption)
                            .foregroundStyle(NL.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    } else {
                        Text("No stories yet")
                            .font(NLFont.caption)
                            .foregroundStyle(NL.textTertiary)
                    }
                }
                .padding(NLMetrics.cardPadding * 0.75)
            }
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .clipShape(RoundedRectangle(cornerRadius: NLMetrics.cardRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: NLMetrics.cardRadius, style: .continuous))
        }
        .nlCardButton()
        .accessibilityElement(children: .combine)
    }
}
