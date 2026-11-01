import SwiftUI

struct CountriesView: View {
    @Environment(FeedStore.self) private var store
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    var body: some View {
        content
            .background(NLBackground())
            #if !os(tvOS)
            .navigationTitle("Countries")
            #endif
    }

    @ViewBuilder private var content: some View {
        #if os(tvOS)
        CountryColumnsTV()
        #elseif os(iOS)
        if sizeClass == .compact { CountryPickerList() } else { CountryOverview() }
        #else
        CountryOverview()
        #endif
    }
}

/// Header band for one country: its aurora, code, name, count and local time.
struct CountryBand: View {
    let country: Country
    var height: CGFloat

    @Environment(FeedStore.self) private var store

    var body: some View {
        let count = store.news(in: country).count
        ZStack(alignment: .bottomLeading) {
            AuroraArt(country: country.rawValue)
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    CountryChip(code: country.rawValue)
                    Text(country.name).font(NLFont.section).foregroundStyle(NL.textPrimary)
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        let moment = SnapshotMode.isOn ? SnapshotMode.frozenDate : context.date
                        Text(verbatim: "\(country.capitalName) \(Self.clock(moment, in: country.timeZone))")
                            .font(NLFont.caption)
                            .monospacedDigit()
                            .foregroundStyle(NL.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                Spacer()
                Text(count, format: .number)
                    .font(NLFont.dateDay)
                    .foregroundStyle(count > 0 ? NL.textPrimary : NL.textTertiary)
                    .contentTransition(.numericText())
            }
            .padding(NLMetrics.cardPadding * 0.75)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: NLMetrics.cardRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    static func clock(_ date: Date, in zone: TimeZone) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened, locale: Locale(identifier: "en_GB"))
        style.timeZone = zone
        return date.formatted(style)
    }
}

struct QuietCountry: View {
    let country: Country

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "snowflake").font(NLFont.section)
            Text("Quiet in \(country.name) — no stories this week")
                .font(NLFont.caption)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(NL.textTertiary)
        .frame(maxWidth: .infinity, minHeight: 140)
        .padding()
        .nlGlass(cornerRadius: NLMetrics.rowRadius)
    }
}

#if os(tvOS)
private struct CountryColumnsTV: View {
    @Environment(FeedStore.self) private var store

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 28) {
                ForEach(Country.allCases) { country in
                    let items = store.news(in: country)
                    LazyVStack(alignment: .leading, spacing: 20) {
                        CountryBand(country: country, height: 180)
                        if items.isEmpty { QuietCountry(country: country) }
                        ForEach(items) { NewsRow(item: $0, lines: 4) }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .focusSection()
                }
            }
            .padding(.horizontal, NLMetrics.margin)
            .padding(.vertical, 30)
        }
        .scrollClipDisabled()
    }
}
#endif

#if !os(tvOS)
/// iPad, Mac, Vision Pro: five tiles, each opens the country's list.
private struct CountryOverview: View {
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: NLMetrics.gutter)], spacing: NLMetrics.gutter) {
                ForEach(Country.allCases) { CountryTile(country: $0, height: 220) }
            }
            .padding(NLMetrics.margin)
        }
    }
}
#endif

#if os(iOS)
/// iPhone: a segmented picker over one country's list.
private struct CountryPickerList: View {
    @SceneStorage("countries.selected") private var selected = Country.no.rawValue
    @Environment(FeedStore.self) private var store

    var body: some View {
        let country = Country(rawValue: selected) ?? .no
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Picker("Country", selection: $selected) {
                    ForEach(Country.allCases) { c in
                        Text(verbatim: c.rawValue)
                            .accessibilityLabel(Text("\(c.name), \(store.news(in: c).count) stories"))
                            .tag(c.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                CountryBand(country: country, height: 150)
                let items = store.news(in: country)
                if items.isEmpty { QuietCountry(country: country) }
                ForEach(items) { NewsRow(item: $0, lines: 3) }
            }
            .padding(NLMetrics.margin)
        }
    }
}
#endif

/// One country's stories, pushed from a tile.
struct CountryNewsView: View {
    let country: Country
    @Environment(FeedStore.self) private var store

    var body: some View {
        let items = store.news(in: country)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                CountryBand(country: country, height: 160)
                if items.isEmpty { QuietCountry(country: country) }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: NLMetrics.gutter, alignment: .top)],
                          spacing: NLMetrics.gutter) {
                    ForEach(items) { NewsRow(item: $0, lines: 3) }
                }
            }
            .padding(NLMetrics.margin)
            .frame(maxWidth: 1280)
            .frame(maxWidth: .infinity)
        }
        .background(NLBackground())
        #if !os(tvOS)
        .navigationTitle(country.name)
        #endif
    }
}
