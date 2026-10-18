import SwiftUI

struct EventsView: View {
    @Environment(FeedStore.self) private var store
    @State private var showPast = false
    @State private var width: CGFloat = 0

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: NLMetrics.gutter) {
                if store.upcomingEvents.isEmpty {
                    Text("No upcoming events")
                        .font(NLFont.body)
                        .foregroundStyle(NL.textTertiary)
                }
                ForEach(Self.byMonth(store.upcomingEvents), id: \.month) { group in
                    SectionHeader(title: LocalizedStringKey(Formats.month(group.month, lang: store.lang)))
                        .padding(.top, 12)
                    grid(group.events, nextID: store.upcomingEvents.first?.id)
                }
                if !store.pastEvents.isEmpty {
                    Button {
                        withAnimation(.smooth) { showPast.toggle() }
                    } label: {
                        Label(showPast ? "Hide past events" : "Show past events (\(store.pastEvents.count))",
                              systemImage: showPast ? "chevron.up" : "chevron.down")
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 20)
                    if showPast {
                        grid(store.pastEvents, nextID: nil).opacity(0.65)
                    }
                }
            }
            .padding(.horizontal, NLMetrics.margin)
            .padding(.vertical, 24)
            .frame(maxWidth: 1400)
            .frame(maxWidth: .infinity)
        }
        .scrollClipDisabled()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .background(NLBackground())
        #if !os(tvOS)
        .navigationTitle("Events")
        #endif
    }

    private func grid(_ events: [EventItem], nextID: String?) -> some View {
        let columns = width >= 700 ? 2 : 1
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: NLMetrics.gutter, alignment: .top), count: columns),
                         spacing: NLMetrics.gutter) {
            ForEach(events) { EventRowCard(event: $0, isNext: $0.id == nextID) }
        }
        #if os(tvOS)
        .focusSection()
        #endif
    }

    static func byMonth(_ events: [EventItem]) -> [(month: Date, events: [EventItem])] {
        let cal = Calendar.current
        var groups: [(month: Date, events: [EventItem])] = []
        for event in events {
            let start = event.start ?? .distantFuture
            let month = cal.date(from: cal.dateComponents([.year, .month], from: start)) ?? start
            if groups.last?.month == month {
                groups[groups.count - 1].events.append(event)
            } else {
                groups.append((month: month, events: [event]))
            }
        }
        return groups
    }
}

struct EventRowCard: View {
    let event: EventItem
    var isNext = false
    @Environment(FeedStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        Button { router.open(.event(event)) } label: {
            HStack(spacing: 0) {
                Rectangle().fill(NL.country(event.country)).frame(width: 4)
                HStack(alignment: .top, spacing: 18) {
                    DateTile(date: event.start, country: event.country, lang: store.lang)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Text(timeRange)
                                .font(NLFont.kicker)
                                .monospacedDigit()
                                .foregroundStyle(NL.textSecondary)
                            if isNext {
                                Text("Next")
                                    .font(NLFont.caption.weight(.bold))
                                    .foregroundStyle(NL.bg)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 2)
                                    .background(NL.accent, in: Capsule())
                            }
                        }
                        Text(event.title)
                            .font(NLFont.row)
                            .foregroundStyle(NL.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(verbatim: [event.online ? String(localized: "Online", bundle: AppLanguage.bundle) : event.city, event.organiser]
                            .compactMap { $0 }.joined(separator: " · "))
                            .font(NLFont.caption)
                            .foregroundStyle(NL.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 8) {
                        CountryChip(code: event.country)
                        EntryBadge(event: event)
                    }
                }
                .padding(NLMetrics.cardPadding * 0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .nlGlass(cornerRadius: NLMetrics.rowRadius)
            .clipShape(RoundedRectangle(cornerRadius: NLMetrics.rowRadius, style: .continuous))
            .contentShape(Rectangle())
        }
        .nlCardButton()
        .accessibilityElement(children: .combine)
    }

    private var timeRange: String {
        let start = Formats.time(event.start, lang: store.lang)
        guard let end = event.end, let begin = event.start, Calendar.current.isDate(begin, inSameDayAs: end) else { return start }
        return "\(start)–\(Formats.time(end, lang: store.lang))"
    }
}
