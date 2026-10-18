#if os(tvOS)
import SwiftUI

/// The "Kveldsnytt" Apple TV page: a broadcast-style front page. A large lead
/// story with an aurora glow, cards under it, and the agenda and spotlight
/// on the right. Every part keeps its place and rotates its own content.
struct KveldsnyttLayout: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            K.ground
            Circle()
                .fill(NL.accent)
                .frame(width: 1300, height: 900)
                .blur(radius: 140)
                .opacity(0.20)
                .offset(x: -200, y: -260)
            VStack(alignment: .leading, spacing: 28) {
                KHeader()
                HStack(alignment: .top, spacing: 40) {
                    VStack(alignment: .leading, spacing: 24) {
                        KLead()
                        KCards()
                            .frame(height: 240)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    VStack(spacing: 18) {
                        KAgenda()
                        SpotlightModule(compact: true)
                            .frame(height: 196)   // room for the description sentence (2 lines)
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                            Text("Open source on GitHub")
                            Text(verbatim: "github.com/jQrgen/nordic-crypto-tv")
                                .foregroundStyle(NL.textSecondary)
                        }
                        .font(.system(size: 14))
                        .foregroundStyle(NL.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .frame(width: 620)
                }
                .frame(maxHeight: .infinity)
            }
            .padding(.horizontal, 64)
            .padding(.vertical, 44)
        }
    }
}

/// Colours of the Kveldsnytt design.
private enum K {
    static let ground = Color(hex: 0x06090F)
    static let panel = Color(hex: 0x0F1522)
    static let aside = Color(hex: 0x0D1320)
    static let raised = Color(hex: 0x1A2232)
    static let rule = Color(hex: 0x1E2738)
    static let body = Color(hex: 0xC9D1DF)

    static func serif(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

// MARK: - Header

private struct KHeader: View {
    @Environment(FeedStore.self) private var store

    var body: some View {
        HStack(alignment: .center, spacing: 28) {
            Wordmark(size: 44)
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(context.date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Formats.locale(store.lang))))
                    .font(.system(size: 20))
                    .foregroundStyle(NL.textSecondary)
            }
            StatusPill(store: store)
            Spacer(minLength: 12)
            HStack(spacing: 8) {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(Color(hex: 0x229ED9))
                Text(verbatim: "Telegram")
                    .foregroundStyle(NL.textSecondary)
                Text(verbatim: APIConfig.telegramHandle)
                    .fontWeight(.semibold)
                    .foregroundStyle(NL.textPrimary)
            }
            .font(.system(size: 20))
            .fixedSize()
            RadioPill()
                .fixedSize()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(Formats.time(context.date, lang: store.lang))
                    .font(.system(size: 52, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(NL.textPrimary)
            }
        }
    }
}

// MARK: - Lead

/// The five newest stories, one at a time, in large serif type.
private struct KLead: View {
    @Environment(FeedStore.self) private var store

    var body: some View {
        let top = Array(store.news.prefix(5))
        Rotating(items: top, interval: 15) { item, index in
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 14) {
                    Kicker(item: item, lang: store.lang)
                    Spacer()
                    PageDots(count: top.count, index: index)
                }
                Text(item.headline(for: store.lang))
                    .font(K.serif(88))
                    .tracking(-1.5)
                    .foregroundStyle(NL.textPrimary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                if let original = item.originalHeadline(for: store.lang) {
                    Text(original)
                        .font(.system(size: 24)).italic()
                        .foregroundStyle(NL.textTertiary)
                        .lineLimit(1)
                }
                HStack(alignment: .bottom, spacing: 32) {
                    if let summary = item.summary(for: store.lang) {
                        Text(summary)
                            .font(.system(size: 30))
                            .lineSpacing(6)
                            .foregroundStyle(K.body)
                            .lineLimit(3)
                            .frame(maxWidth: 1000, alignment: .leading)
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Cards under the lead

/// Two pages of further headlines and the newsletter.
private struct KCards: View {
    @Environment(FeedStore.self) private var store

    var body: some View {
        let pages = Array(store.news.dropFirst(5)).chunked(2)
        HStack(spacing: 20) {
            Rotating(items: pages, interval: 14, offset: 3) { page, _ in
                HStack(spacing: 20) {
                    ForEach(Array(page.enumerated()), id: \.offset) { _, item in
                        StoryCard(item: item)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            NewsletterCardK()
                .frame(width: 420)
        }
    }
}

private struct StoryCard: View {
    let item: NewsItem
    @Environment(FeedStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SourceLogo(name: item.sourceName, url: store.logo(for: item), size: 24)
                Text(verbatim: [item.country, item.sourceName, Formats.stamp(item.published, lang: store.lang)]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(NL.country(item.country))
                    .lineLimit(1)
            }
            Text(item.headline(for: store.lang))
                .font(K.serif(27, .semibold))
                .foregroundStyle(NL.textPrimary)
                .lineLimit(4)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(K.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct NewsletterCardK: View {
    @Environment(FeedStore.self) private var store

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            if let latest = store.issues.first {
                let issue = store.issue(latest.id) ?? latest
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: "No. \(issue.number ?? 0) · \(issue.date.flatMap(NewsletterCard.parse).map { Formats.day($0, lang: store.lang) } ?? "")")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(NL.accent2)
                    Text(issue.title(for: store.lang))
                        .font(K.serif(23, .semibold))
                        .foregroundStyle(NL.textPrimary)
                        .lineLimit(4)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(K.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background {
            AuroraArt.newsletter(seed: "newsletter").opacity(0.3)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

// MARK: - Agenda

/// Coming up: one featured event, then the next four in a
/// ruled list. The featured event moves on every 15 seconds.
private struct KAgenda: View {
    @Environment(FeedStore.self) private var store

    var body: some View {
        let events = store.upcomingEvents
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Coming up")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(NL.textPrimary)
                Spacer()
                Text("\(events.count) events")
                    .font(.system(size: 20))
                    .foregroundStyle(NL.textTertiary)
            }
            if events.isEmpty {
                Text("No upcoming events").font(.system(size: 22)).foregroundStyle(NL.textTertiary)
            } else {
                AgendaTimeline(events: events, shown: min(7, events.count), interval: 15, offset: 7)
                Rotating(items: Array(events.indices), interval: 15, offset: 7) { i, _ in
                    VStack(alignment: .leading, spacing: 6) {
                        FeaturedEventK(event: events[i], isNext: i == 0)
                        ForEach(1..<min(7, events.count), id: \.self) { k in
                            EventRowK(event: events[(i + k) % events.count], last: k == min(7, events.count) - 1)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(K.aside, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

/// Date axis over the agenda: today, months ahead, every event as a dot,
/// the events on screen highlighted, and a bar filling up to the next switch.
private struct AgendaTimeline: View {
    let events: [EventItem]
    let shown: Int
    let interval: Double
    let offset: Double
    @Environment(FeedStore.self) private var store

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let t = context.date.timeIntervalSinceReferenceDate + offset
            let page = Rotating<Int, EmptyView>.freeze ?? (Int(t / interval) % events.count)
            let progress = Rotating<Int, EmptyView>.freeze == nil ? (t / interval).truncatingRemainder(dividingBy: 1) : 0
            GeometryReader { geo in
                axis(page: page, width: geo.size.width, now: context.date)
            }
            .frame(height: 36)
            .overlay(alignment: .bottomLeading) {
                GeometryReader { geo in
                    Capsule().fill(K.rule)
                    Capsule().fill(NL.accent)
                        .frame(width: geo.size.width * progress)
                        .animation(progress < 0.1 ? nil : .linear(duration: 1), value: progress)
                }
                .frame(height: 4)
                .offset(y: 8)
            }
            .padding(.bottom, 8)
        }
        .accessibilityHidden(true)
    }

    private func axis(page: Int, width: CGFloat, now: Date) -> some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let last = events.compactMap(\.start).max() ?? today
        let end = max(last, cal.date(byAdding: .day, value: 30, to: today) ?? last)
        let span = max(end.timeIntervalSince(today), 1)
        let inset: CGFloat = 8
        func x(_ date: Date) -> CGFloat {
            inset + (width - 2 * inset) * CGFloat(min(max(date.timeIntervalSince(today) / span, 0), 1))
        }
        let window = (0..<shown).map { (page + $0) % events.count }
        let runs = [window.prefix { $0 >= page }, window.drop { $0 >= page }].filter { !$0.isEmpty }
        let months = sequence(first: cal.dateInterval(of: .month, for: today)?.end ?? end) {
            cal.date(byAdding: .month, value: 1, to: $0)
        }.prefix { $0 <= end }
        let lineY: CGFloat = 26

        return ZStack(alignment: .topLeading) {
            Rectangle().fill(K.rule).frame(height: 2).offset(y: lineY - 1)
            ForEach(Array(months), id: \.self) { month in
                Rectangle().fill(K.rule).frame(width: 2, height: 12).offset(x: x(month) - 1, y: lineY - 6)
                if x(month) > 70, x(month) < width - 44 {
                    Text(month.formatted(.dateTime.month(.abbreviated).locale(Formats.locale(store.lang))))
                        .font(.system(size: 14, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(NL.textTertiary)
                        .fixedSize()
                        .offset(x: x(month) + 5)
                }
            }
            Text("Today")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(NL.accent)
                .fixedSize()
            ForEach(Array(runs.enumerated()), id: \.offset) { _, run in
                if let a = events[run.first!].start, let b = events[run.last!].start {
                    Capsule()
                        .fill(NL.accent.opacity(0.22))
                        .frame(width: x(b) - x(a) + 18, height: 18)
                        .offset(x: x(a) - 9, y: lineY - 9)
                }
            }
            ForEach(Array(events.enumerated()), id: \.offset) { i, event in
                if let start = event.start {
                    let d: CGFloat = i == page ? 14 : 8
                    Circle()
                        .fill(NL.country(event.country).opacity(window.contains(i) ? 1 : 0.35))
                        .frame(width: d, height: d)
                        .overlay { if i == page { Circle().stroke(NL.textPrimary, lineWidth: 2) } }
                        .offset(x: x(start) - d / 2, y: lineY - d / 2)
                }
            }
            Rectangle().fill(NL.accent).frame(width: 2, height: 20).offset(x: inset - 1, y: lineY - 10)
        }
        .frame(width: width, alignment: .topLeading)
        .animation(.smooth(duration: 0.9), value: page)
    }
}

private struct FeaturedEventK: View {
    let event: EventItem
    let isNext: Bool
    @Environment(FeedStore.self) private var store

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(spacing: 0) {
                Text(event.start.map { Formats.dayNumber($0, lang: store.lang) } ?? "–")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(NL.textPrimary)
                Text(event.start.map { $0.formatted(.dateTime.month(.abbreviated).locale(Formats.locale(store.lang))) } ?? "")
                    .font(.system(size: 18, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(NL.country(event.country))
            }
            .frame(width: 96)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text(when)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(NL.accent)
                        .lineLimit(1)
                    if isNext {
                        Text("Next")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(K.ground)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 2)
                            .background(NL.accent, in: Capsule())
                    }
                }
                Text(event.title)
                    .font(K.serif(30))
                    .foregroundStyle(NL.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: [event.online ? String(localized: "Online") : event.city, event.organiser]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 18))
                    .foregroundStyle(NL.textSecondary)
                    .lineLimit(1)
                if let going = event.going, going > 0 {
                    Label("\(going) going", systemImage: "person.2.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(NL.accent)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(22)
        .background(K.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var when: String {
        guard let start = event.start else { return "" }
        let day = start.formatted(.dateTime.weekday(.abbreviated).locale(Formats.locale(store.lang)))
        let from = Formats.time(start, lang: store.lang)
        if let end = event.end, Calendar.current.isDate(start, inSameDayAs: end) {
            return "\(day) · \(from)–\(Formats.time(end, lang: store.lang))"
        }
        return "\(day) · \(from)"
    }
}

private struct EventRowK: View {
    let event: EventItem
    let last: Bool
    @Environment(FeedStore.self) private var store

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(spacing: 0) {
                Text(event.start.map { Formats.dayNumber($0, lang: store.lang) } ?? "–")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(NL.textPrimary)
                Text(event.start.map { $0.formatted(.dateTime.month(.abbreviated).locale(Formats.locale(store.lang))) } ?? "")
                    .font(.system(size: 13, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(NL.country(event.country))
            }
            .frame(width: 64)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(NL.textPrimary)
                    .lineLimit(1)
                Text(verbatim: [event.online ? String(localized: "Online") : event.city,
                                Formats.time(event.start, lang: store.lang), event.organiser]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 17))
                    .foregroundStyle(NL.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let going = event.going, going > 0 {
                Label("\(going) going", systemImage: "person.2.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NL.textSecondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            EntryBadge(event: event)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 6)
        .overlay(alignment: .bottom) {
            if !last { Rectangle().fill(K.rule).frame(height: 1) }
        }
    }
}

#endif
