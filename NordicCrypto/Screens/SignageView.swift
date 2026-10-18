#if os(tvOS)
import SwiftUI

/// Apple TV runs as an information screen ("Kveldsnytt" design): one page
/// whose parts stay in place while each rotates its own content, so the
/// viewer never loses context. Play/Pause switches the radio on and off and
/// Select changes station. The page takes
/// focus at launch so the tab bar slides away; Menu or up brings it back.
struct SignageView: View {
    @Environment(Radio.self) private var radio
    @FocusState private var focused: Bool
    @State private var launched = false

    var body: some View {
        KveldsnyttLayout()
            .frame(width: 1920, height: 1080)
            .ignoresSafeArea()
            .focusable()
            .focusEffectDisabled()
            .focused($focused)
            .accessibilityElement(children: .contain)
            .onAppear {
                guard !launched else { return }
                launched = true
                focused = true
            }
            .onPlayPauseCommand { radio.toggle() }
            .onTapGesture { radio.next() }
    }
}

// MARK: - Rotation

/// Shows one page of `items` at a time and moves on every `interval`
/// seconds. Stateless: the page comes from the clock, so modules with
/// different offsets change at different moments.
struct Rotating<Item, Content: View>: View {
    let items: [Item]
    var interval: Double
    var offset: Double = 0
    @ViewBuilder var content: (Item, Int) -> Content

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let tick = Int((context.date.timeIntervalSinceReferenceDate + offset) / interval)
                let index = Self.freeze ?? (tick % items.count)
                ZStack {
                    content(items[index], index)
                        .id(index)
                        .transition(.opacity)
                }
                .animation(.easeInOut(duration: 0.9), value: index)
            }
        }
    }

    /// `-NCFreeze` keeps every module on its first page, for screenshots.
    static var freeze: Int? {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-NCFreeze") ? 0 : nil
        #else
        nil
        #endif
    }
}

/// Page marker for a rotating module.
struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        if count > 1 {
            HStack(spacing: 6) {
                ForEach(0..<count, id: \.self) { i in
                    Capsule()
                        .fill(i == index ? NL.accent : NL.textTertiary.opacity(0.4))
                        .frame(width: i == index ? 22 : 8, height: 8)
                }
            }
            .animation(.smooth, value: index)
            .accessibilityHidden(true)
        }
    }
}

private struct ModuleHeader: View {
    let title: LocalizedStringKey
    var count: Int? = nil
    var pages: Int = 1
    var page: Int = 0

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(NL.textSecondary)
            if let count {
                Text(count, format: .number)
                    .font(.system(size: 24, weight: .regular, design: .rounded))
                    .foregroundStyle(NL.textTertiary)
            }
            Spacer()
            PageDots(count: pages, index: page)
        }
    }
}

extension View {
    func module(padding: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(NL.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(NL.hairline))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

/// Radio status, with the hint that the remote's Play/Pause controls it.
struct RadioPill: View {
    @Environment(Radio.self) private var radio

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: radio.isOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .symbolEffect(.variableColor.iterative, isActive: radio.isPlaying)
                .foregroundStyle(radio.isOn ? NL.accent : NL.textTertiary)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: radio.station.name)
                    .font(NLFont.kicker)
                    .foregroundStyle(NL.textPrimary)
                Text(radio.isOn ? "Press ⏯ to turn off" : "Press ⏯ to turn on")
                    .font(NLFont.caption)
                    .foregroundStyle(NL.textTertiary)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(NL.surface.opacity(0.8), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("radio")
        .accessibilityValue(Text(radio.isOn ? "On" : "Off"))
    }
}

// MARK: - Modules

struct CompactDate: View {
    let date: Date?
    let country: String?
    let lang: String

    var body: some View {
        VStack(spacing: -2) {
            Text(date.map { Formats.dayNumber($0, lang: lang) } ?? "–")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(NL.textPrimary)
            Text(date.map { $0.formatted(.dateTime.month(.abbreviated).locale(Formats.locale(lang))) } ?? "")
                .font(.system(size: 13, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(NL.country(country))
        }
        .frame(width: 58, height: 50)
        .background(NL.country(country).opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Someone or something from the Nordic crypto world, picked at random:
/// people, companies, public bodies, courses, research and student groups.
struct SpotlightModule: View {
    /// One slim row (portrait, name, role) for a page where events need the room.
    var compact = false
    @Environment(FeedStore.self) private var store

    var body: some View {
        if compact {
            compactBody
        } else {
            fullBody
        }
    }

    private var compactBody: some View {
        Rotating(items: store.spotlight, interval: 12, offset: 5) { item, _ in
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 16) {
                    picture(item, side: 72)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text("Spotlight")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(NL.textTertiary)
                            Text(kind(item))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(NL.accent2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 1)
                                .background(NL.accent2.opacity(0.15), in: Capsule())
                            if let country = country(item) {
                                Text(verbatim: country)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(NL.country(country))
                            }
                        }
                        Text(verbatim: name(item))
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundStyle(NL.textPrimary)
                            .lineLimit(1)
                        if let line = subtitle(item) {
                            Text(verbatim: line)
                                .font(.system(size: 16))
                                .foregroundStyle(NL.textSecondary)
                                .lineLimit(1)
                        }
                        // A sentence about who or what is shown (who's-who description, course "about").
                        if let text = detail(item) {
                            Text(verbatim: text)
                                .font(.system(size: 17))
                                .foregroundStyle(NL.textSecondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
                if let credit = credit(item) {
                    Text(isPhoto(item) ? "Photo: \(credit)" : "Logo: \(credit)")
                        .font(.system(size: 11))
                        .foregroundStyle(NL.textTertiary)
                        .lineLimit(1)
                }
            }
        }
        .module(padding: 18)
    }

    private var fullBody: some View {
        Rotating(items: store.spotlight, interval: 12, offset: 5) { item, _ in
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text("Spotlight")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(NL.textSecondary)
                    Spacer()
                    Text(kind(item))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(NL.accent2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(NL.accent2.opacity(0.15), in: Capsule())
                    if let country = country(item) { CountryChip(code: country) }
                }
                HStack(alignment: .top, spacing: 18) {
                    picture(item)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(verbatim: name(item))
                            .font(.system(size: 24, weight: .semibold, design: .serif))
                            .foregroundStyle(NL.textPrimary)
                            .lineLimit(2)
                        if let line = subtitle(item) {
                            Text(verbatim: line)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(NL.textSecondary)
                                .lineLimit(2)
                        }
                        if let text = detail(item) {
                            Text(verbatim: text)
                                .font(.system(size: 16))
                                .foregroundStyle(NL.textTertiary)
                                .lineLimit(3)
                        }
                    }
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
                if let credit = credit(item) {
                    Text(isPhoto(item) ? "Photo: \(credit)" : "Logo: \(credit)")
                        .font(.system(size: 13))
                        .foregroundStyle(NL.textTertiary)
                        .lineLimit(1)
                }
            }
        }
        .module()
    }

    @ViewBuilder private func picture(_ item: SpotlightItem, side: CGFloat = 104) -> some View {
        switch item {
        case .entity(let e):
            let image = e.image ?? e.logo
            if let url = image?.displayableURL {
                AsyncImage(url: APIConfig.reachable(url)) { img in
                    if e.isPerson {
                        img.resizable().scaledToFill()
                    } else {
                        img.resizable().scaledToFit().padding(10).background(.white)
                    }
                } placeholder: {
                    SourceLogo(name: e.name, url: nil, size: side)
                }
                .frame(width: side, height: side)
                .clipShape(e.isPerson ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 22, style: .continuous)))
            } else if e.isPerson {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(NL.textTertiary)
                    .frame(width: side, height: side)
            } else {
                SourceLogo(name: e.name, url: nil, size: side)
            }
        case .academia(let a):
            ZStack {
                AuroraArt(seed: a.id, primary: NL.accent2, secondary: NL.country(a.country), scrim: false)
                Image(systemName: symbol(a))
                    .font(.system(size: side * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private func kind(_ item: SpotlightItem) -> LocalizedStringKey {
        switch item {
        case .entity(let e):
            if e.isPerson { return "Person" }
            return e.sector == "public" ? "Public body" : "Company"
        case .academia(let a):
            switch a.section {
            case "courses": return "Course"
            case "groups": return "Student group"
            case "publications": return "Paper"
            default: return "Research"
            }
        }
    }

    private func symbol(_ a: AcademiaItem) -> String {
        switch a.section {
        case "courses": "graduationcap.fill"
        case "groups": "person.3.fill"
        case "publications": "doc.text.fill"
        default: "flask.fill"
        }
    }

    private func country(_ item: SpotlightItem) -> String? {
        switch item {
        case .entity(let e): e.country
        case .academia(let a): a.country
        }
    }

    private func name(_ item: SpotlightItem) -> String {
        switch item {
        case .entity(let e): e.name
        case .academia(let a): a.name
        }
    }

    private func subtitle(_ item: SpotlightItem) -> String? {
        switch item {
        case .entity(let e):
            if e.isPerson {
                let org = e.org.flatMap { store.entities[$0]?.name }
                let line = [e.role, org].compactMap { $0 }.joined(separator: " · ")
                return line.isEmpty ? nil : line
            }
            return e.group
        case .academia(let a):
            let line = [a.institution, a.code, a.level].compactMap { $0 }.joined(separator: " · ")
            return line.isEmpty ? nil : line
        }
    }

    private func detail(_ item: SpotlightItem) -> String? {
        switch item {
        case .entity(let e): e.description
        case .academia(let a): a.about(for: store.lang)
        }
    }

    private func isPhoto(_ item: SpotlightItem) -> Bool {
        if case .entity(let e) = item { return e.image != nil }
        return false
    }

    private func credit(_ item: SpotlightItem) -> String? {
        guard case .entity(let e) = item, let image = e.image ?? e.logo, image.displayableURL != nil,
              image.license?.lowercased() != "public domain" else { return nil }
        return image.creditLine
    }
}

extension Array {
    /// Pages of `size`; the last page is topped up from the start so every
    /// page is full and the module never shows a half-empty panel.
    func chunked(_ size: Int) -> [[Element]] {
        guard count > size else { return isEmpty ? [] : [self] }
        let pages = (count + size - 1) / size
        return (0..<pages).map { page in (0..<size).map { self[(page * size + $0) % count] } }
    }
}
#endif
