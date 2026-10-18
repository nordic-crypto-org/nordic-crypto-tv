import SwiftUI
import AVKit

// MARK: - Surfaces

extension View {
    /// Frosted card surface: Liquid Glass on 26+, material before that, solid
    /// when the reader asked for less transparency.
    func nlGlass(cornerRadius: CGFloat = NLMetrics.cardRadius) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius))
    }

    /// Makes a card-shaped button behave natively: system lift on Apple TV,
    /// pointer/gaze lift on iPad and Vision Pro, subtle hover on Mac.
    func nlCardButton() -> some View {
        modifier(CardButton())
    }
}

private struct GlassSurface: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        #if os(tvOS)
        // Inside a .card button the system draws the lift; keep the fill flat.
        content.background(NL.surface, in: shape)
        #elseif os(visionOS)
        content.background(.regularMaterial, in: shape)
        #else
        if reduceTransparency {
            content.background(NL.surface, in: shape).overlay(shape.stroke(NL.hairline))
        } else if #available(iOS 26, macOS 26, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content.background(.ultraThinMaterial, in: shape).overlay(shape.stroke(NL.hairline))
        }
        #endif
    }
}

private struct CardButton: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        #if os(tvOS)
        content.buttonStyle(.card)
        #elseif os(macOS)
        content
            .buttonStyle(PressStyle())
            .brightness(hovering ? 0.04 : 0)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
        #else
        content
            .buttonStyle(PressStyle())
            .hoverEffect(.lift)
        #endif
    }
}

private struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.smooth(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Chips and badges

struct CountryChip: View {
    let code: String?

    var body: some View {
        let color = NL.country(code)
        Text(verbatim: code ?? "—")
            .font(NLFont.kicker.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, chipPadding)
            .padding(.vertical, chipPadding * 0.35)
            .background(color.opacity(0.18), in: Capsule())
            .accessibilityLabel(Text(Country(rawValue: code ?? "")?.name ?? code ?? ""))
    }

    private var chipPadding: CGFloat {
        #if os(tvOS)
        14
        #else
        8
        #endif
    }
}

struct TopicChip: View {
    let topic: String

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(NL.topic(topic)).frame(width: dot, height: dot)
            Text(verbatim: Self.label(topic))
                .font(NLFont.caption.weight(.medium))
                .foregroundStyle(NL.textSecondary)
        }
        .padding(.horizontal, dot * 1.6)
        .padding(.vertical, dot * 0.6)
        .background(NL.hairline, in: Capsule())
    }

    private var dot: CGFloat {
        #if os(tvOS)
        10
        #else
        6
        #endif
    }

    static func label(_ topic: String) -> String {
        let acronyms = ["mica": "MiCA", "aml": "AML", "defi": "DeFi", "cbdc": "CBDC", "nft": "NFT"]
        return acronyms[topic.lowercased()] ?? topic.prefix(1).uppercased() + topic.dropFirst()
    }
}

struct PaywallBadge: View {
    var body: some View {
        Label("Paywall", systemImage: "lock.fill")
            .font(NLFont.caption.weight(.semibold))
            .foregroundStyle(NL.warning)
            .labelStyle(.titleAndIcon)
    }
}

struct EntryBadge: View {
    let event: EventItem

    var body: some View {
        if let (label, symbol, color) = content {
            Label(label, systemImage: symbol)
                .font(NLFont.caption.weight(.semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .overlay(Capsule().stroke(color.opacity(0.6), lineWidth: 1))
        }
    }

    private var content: (LocalizedStringKey, String, Color)? {
        if event.sponsored != nil { return ("Sponsored", "star.fill", NL.warning) }
        if event.online { return ("Online", "globe", NL.accent2) }
        switch event.paid {
        case true?: return ("Paid", "ticket", NL.textSecondary)
        case false?: return ("Free", "checkmark", NL.accent)
        default: return nil
        }
    }
}

struct DateTile: View {
    let date: Date?
    let country: String?
    let lang: String

    var body: some View {
        VStack(spacing: 0) {
            Text(date.map { Formats.dayNumber($0, lang: lang) } ?? "–")
                .font(NLFont.dateDay)
                .monospacedDigit()
                .foregroundStyle(NL.textPrimary)
            Text(date.map { $0.formatted(.dateTime.month(.abbreviated).locale(Formats.locale(lang))) } ?? "")
                .font(NLFont.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(NL.country(country))
        }
        .frame(width: side, height: side)
        .background(NL.country(country).opacity(0.15), in: RoundedRectangle(cornerRadius: side * 0.24, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(date.map { $0.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Formats.locale(lang))) } ?? ""))
    }

    private var side: CGFloat {
        #if os(tvOS)
        96
        #elseif os(visionOS)
        72
        #else
        58
        #endif
    }
}

struct SectionHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    var count: Int? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title).font(NLFont.section).foregroundStyle(NL.textPrimary)
            if let count {
                Text(count, format: .number)
                    .font(NLFont.section.weight(.regular))
                    .foregroundStyle(NL.textTertiary)
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
            trailing()
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(title: LocalizedStringKey, count: Int? = nil) {
        self.init(title: title, count: count) { EmptyView() }
    }
}

struct StatusPill: View {
    let store: FeedStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 9, height: 9)
                .opacity(pulse ? 0.4 : 1)
            Text(label)
                .font(NLFont.caption.weight(.medium))
                .foregroundStyle(NL.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(NL.hairline, in: Capsule())
        .onAppear {
            guard !reduceMotion, case .live = store.status else { return }
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityElement(children: .combine)
    }

    private var dotColor: Color {
        switch store.status {
        case .live: NL.accent
        case .loading: NL.textTertiary
        case .offline: NL.danger
        }
    }

    private var label: String {
        let time = Formats.time(store.updated, lang: store.lang)
        switch store.status {
        case .offline: return String(localized: "Offline · showing saved news", bundle: AppLanguage.bundle)
        default: return String(localized: "Updated \(time)", bundle: AppLanguage.bundle)
        }
    }
}

/// The outlet's logo; until one is approved, a monogram in a colour of its
/// own, so a newspaper is always recognisable at a glance.
struct SourceLogo: View {
    let name: String?
    let url: URL?
    var size: CGFloat = {
        #if os(tvOS)
        34
        #else
        20
        #endif
    }()

    var body: some View {
        ZStack {
            // Apple platforms cannot draw SVG; those keep the monogram.
            if let url, url.pathExtension.lowercased() != "svg" {
                AsyncImage(url: APIConfig.reachable(url)) { image in
                    image.resizable().scaledToFit().padding(size * 0.08)
                        .background(.white)
                } placeholder: {
                    monogram
                }
            } else {
                monogram
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .accessibilityHidden(true)
    }

    private var monogram: some View {
        let label = Self.initials(name)
        return RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(Self.color(name))
            .overlay {
                Text(verbatim: label)
                    .font(.system(size: size * (label.count > 2 ? 0.34 : 0.44), weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(size * 0.06)
            }
    }

    /// "E24" stays "E24", "Dagens Næringsliv" becomes "DN", "Realtid" "R".
    static func initials(_ name: String?) -> String {
        let words = (name ?? "?").split(whereSeparator: { $0 == " " || $0 == "-" }).map(String.init)
            .filter { !$0.hasPrefix("(") }
        if let first = words.first, first.count <= 3, first == first.uppercased() { return first }
        return String(words.prefix(2).compactMap(\.first)).uppercased()
    }

    static func color(_ name: String?) -> Color {
        let palette: [UInt32] = [0x5B6CFF, 0x0E8F63, 0xC8323F, 0x9C6F00, 0x1F63D1, 0x0B827A, 0x8B4FD6, 0xC23A6A, 0x2E7D99]
        let h = AuroraArt.hash(name ?? "")
        return Color(hex: palette[Int(h % UInt64(palette.count))])
    }
}

struct Kicker: View {
    let item: NewsItem
    let lang: String
    var showPaywall = true
    @Environment(FeedStore.self) private var store

    var body: some View {
        HStack(spacing: 10) {
            CountryChip(code: item.country)
            SourceLogo(name: item.sourceName, url: store.logo(for: item))
            Text(verbatim: [item.sourceName, Formats.stamp(item.published, lang: lang)].compactMap { $0 }.joined(separator: " · "))
                .font(NLFont.kicker)
                .tracking(0.4)
                .foregroundStyle(NL.textSecondary)
                .lineLimit(1)
            if showPaywall && item.paywall {
                Image(systemName: "lock.fill")
                    .font(NLFont.caption)
                    .foregroundStyle(NL.warning)
                    .accessibilityLabel(Text("Paywall"))
            }
        }
    }
}

struct Disclaimer: View {
    var body: some View {
        Text("Not investment advice · Headlines © their publishers · Summaries by Nordic Crypto")
            .font(NLFont.caption)
            .foregroundStyle(NL.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Video

enum Newsreels {
    /// GitHub release assets are served as application/octet-stream.
    static func player(for url: URL) -> AVPlayer {
        let asset = AVURLAsset(url: url, options: [AVURLAssetOverrideMIMETypeKey: "video/mp4"])
        return AVPlayer(playerItem: AVPlayerItem(asset: asset))
    }
}

#if os(tvOS)
/// System player, so the Siri Remote transport controls work as expected.
struct NewsreelPlayer: UIViewControllerRepresentable {
    let url: URL
    var title: String

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player = Newsreels.player(for: url)
        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = title as NSString
        titleItem.extendedLanguageTag = "und"
        player.currentItem?.externalMetadata = [titleItem]
        let controller = AVPlayerViewController()
        controller.player = player
        player.play()
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: ()) {
        controller.player?.pause()
    }
}
#endif

// MARK: - Formatting

enum Formats {
    /// 24-hour clock everywhere; plain English uses British conventions.
    static func locale(_ lang: String) -> Locale {
        Locale(identifier: lang == "en" ? "en_GB" : lang)
    }

    static func time(_ date: Date?, lang: String) -> String {
        guard let date else { return "--:--" }
        return date.formatted(.dateTime.hour().minute().locale(locale(lang)))
    }

    /// Just the day of the month in the language's digits ("14", not "14日"),
    /// for date tiles that show the month on a line of their own.
    static func dayNumber(_ date: Date, lang: String) -> String {
        Calendar.current.component(.day, from: date).formatted(.number.locale(locale(lang)))
    }

    static func day(_ date: Date?, lang: String) -> String {
        guard let date else { return "" }
        return date.formatted(.dateTime.day().month(.abbreviated).locale(locale(lang)))
    }

    static func dayTime(_ date: Date?, lang: String) -> String {
        guard let date else { return "" }
        return date.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(locale(lang)))
    }

    /// The time for today's stories, else the date.
    static func stamp(_ date: Date?, lang: String) -> String {
        guard let date else { return "" }
        return Calendar.current.isDateInToday(date) ? time(date, lang: lang) : day(date, lang: lang)
    }

    /// "Today", "Yesterday", then "Thursday 1 October".
    static func dayHeader(_ date: Date, lang: String) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return String(localized: "Today", bundle: AppLanguage.bundle) }
        if cal.isDateInYesterday(date) { return String(localized: "Yesterday", bundle: AppLanguage.bundle) }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale(lang)))
    }

    static func month(_ date: Date, lang: String) -> String {
        date.formatted(.dateTime.month(.wide).year().locale(locale(lang)))
    }

    static func duration(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// Thin bar filling up until a clock-driven rotation moves on.
struct RotationProgress: View {
    let interval: Double
    var offset: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.25)) { context in
            let t = (context.date.timeIntervalSinceReferenceDate + offset) / interval
            let fraction = t - t.rounded(.down)
            GeometryReader { geo in
                Capsule().fill(NL.textTertiary.opacity(0.2))
                    .overlay(alignment: .leading) {
                        Capsule().fill(NL.accent.opacity(0.7))
                            .frame(width: geo.size.width * fraction)
                    }
            }
            .frame(height: 3)
        }
        .accessibilityHidden(true)
    }
}
