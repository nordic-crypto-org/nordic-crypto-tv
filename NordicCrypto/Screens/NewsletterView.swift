import SwiftUI
import AVKit

struct NewsletterView: View {
    @Environment(FeedStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                if let latest = store.issues.first {
                    IssueHero(issue: store.issue(latest.id) ?? latest)
                } else {
                    Text("No issues yet").font(NLFont.body).foregroundStyle(NL.textTertiary)
                }
                if store.issues.count > 1 {
                    SectionHeader(title: "Past issues", count: store.issues.count - 1)
                    ForEach(store.issues.dropFirst()) { issue in
                        let full = store.issue(issue.id) ?? issue
                        Button { router.open(.reader(full)) } label: {
                            HStack(spacing: 20) {
                                Text(verbatim: "#\(issue.number ?? 0)")
                                    .font(NLFont.dateDay)
                                    .foregroundStyle(NL.accent2)
                                    .frame(minWidth: 70, alignment: .leading)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(issue.title(for: store.lang))
                                        .font(NLFont.row)
                                        .foregroundStyle(NL.textPrimary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Text(verbatim: issue.date ?? "")
                                        .font(NLFont.caption)
                                        .foregroundStyle(NL.textTertiary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(NLMetrics.cardPadding * 0.75)
                            .nlGlass(cornerRadius: NLMetrics.rowRadius)
                            .contentShape(Rectangle())
                        }
                        .nlCardButton()
                    }
                }
            }
            .padding(.horizontal, NLMetrics.margin)
            .padding(.vertical, 24)
            .frame(maxWidth: 1400)
            .frame(maxWidth: .infinity)
        }
        .scrollClipDisabled()
        .background(NLBackground())
        #if !os(tvOS)
        .navigationTitle("Newsletter")
        #endif
    }
}

private struct IssueHero: View {
    let issue: NewsletterIssue
    @Environment(FeedStore.self) private var store
    @Environment(Router.self) private var router
    #if os(visionOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @State private var player: AVPlayer?

    var body: some View {
        #if os(tvOS)
        HStack(alignment: .top, spacing: 48) {
            artwork
            details
        }
        #elseif os(iOS)
        VStack(alignment: .leading, spacing: 24) {
            artwork
            details
        }
        #else
        HStack(alignment: .top, spacing: 40) {
            artwork
            details
        }
        #endif
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(verbatim: "No. \(issue.number ?? 0) · \(issue.date.flatMap(NewsletterCard.parse).map { Formats.day($0, lang: store.lang) } ?? "")")
                .font(NLFont.kicker)
                .foregroundStyle(NL.accent2)
            Text(issue.title(for: store.lang))
                .font(isTV ? NLFont.title : NLFont.display)
                .foregroundStyle(NL.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle = issue.subtitle(for: store.lang) {
                Text(subtitle)
                    .font(NLFont.body)
                    .foregroundStyle(NL.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 28) {
                if let n = issue.stories { Stat(value: "\(n)", label: "Stories") }
                if let n = issue.events { Stat(value: "\(n)", label: "Events") }
                if let d = issue.video?.durationSeconds { Stat(value: Formats.duration(d), label: "Newsreel") }
            }
            actions
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }


    @ViewBuilder private var artwork: some View {
        ZStack {
            if let player {
                VideoPlayer(player: player)
            } else {
                AuroraArt.newsletter(seed: issue.id, animated: isTV)
                if let poster = issue.video?.posterURL {
                    AsyncImage(url: APIConfig.reachable(poster)) { image in
                        image.resizable().aspectRatio(16 / 9, contentMode: .fill).opacity(0.85)
                    } placeholder: { Color.clear }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                }
                if issue.video?.playableURL != nil {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: isTV ? 90 : 56))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, NL.accent2.opacity(0.85))
                }
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .frame(width: isTV ? 640 : nil)
        .frame(maxWidth: 640)
        .clipShape(RoundedRectangle(cornerRadius: NLMetrics.cardRadius, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            if player == nil, let reel = issue.video, let url = reel.playableURL { play(reel, url) }
        }
        .accessibilityHidden(true)
    }

    private func play(_ reel: Newsreel, _ url: URL) {
        #if os(tvOS)
        router.newsreel = reel
        #elseif os(visionOS)
        openWindow(id: "newsreel", value: url)
        #else
        if player == nil { player = Newsreels.player(for: url) }
        player?.play()
        #endif
    }

    private var actions: some View {
        // One row when it fits, otherwise stacked (iPhone, large text).
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { actionButtons }
            VStack(alignment: .leading, spacing: 12) { actionButtons }
        }
        .controlSize(.large)
        #if os(tvOS)
        .focusSection()
        #endif
    }

    @ViewBuilder private var actionButtons: some View {
        if let reel = issue.video, let url = reel.playableURL {
            Button { play(reel, url) } label: {
                Label("Watch newsreel", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .fixedSize()
        }
        if issue.text(for: store.lang) != nil {
            Button { router.open(.reader(issue)) } label: {
                Label("Read issue", systemImage: "text.alignleft")
            }
            .buttonStyle(.bordered)
            .fixedSize()
        }
        #if !os(tvOS)
        Link(destination: APIConfig.subscribe) {
            Label("Subscribe", systemImage: "envelope")
        }
        .buttonStyle(.bordered)
        .fixedSize()
        #endif
    }

    private var isTV: Bool {
        #if os(tvOS)
        true
        #else
        false
        #endif
    }
}

private struct Stat: View {
    let value: String
    let label: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: value)
                .font(NLFont.dateDay)
                .monospacedDigit()
                .foregroundStyle(NL.textPrimary)
            Text(label)
                .font(NLFont.caption)
                .foregroundStyle(NL.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Visions Pro plays the newsreel in its own window beside the app.
struct NewsreelWindow: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player = Newsreels.player(for: url)
                player?.play()
            }
            .onDisappear { player?.pause() }
    }
}

// MARK: - Reader

struct ReaderView: View {
    let issue: NewsletterIssue
    @Environment(FeedStore.self) private var store
    @FocusState private var focusedParagraph: Int?

    var body: some View {
        let paragraphs = (issue.text(for: store.lang) ?? "")
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(issue.title(for: store.lang))
                    .font(NLFont.display)
                    .foregroundStyle(NL.textPrimary)
                    .padding(.bottom, 8)
                Text(verbatim: [issue.stories.map { String(localized: "\($0) stories", bundle: AppLanguage.bundle) },
                                issue.events.map { String(localized: "\($0) events", bundle: AppLanguage.bundle) }]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(NLFont.kicker)
                    .foregroundStyle(NL.accent2)
                    .padding(.bottom, 30)
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, text in
                    ReaderParagraph(text: text, focused: focusedParagraph == index)
                        #if os(tvOS)
                        .focusable()
                        .focused($focusedParagraph, equals: index)
                        #endif
                }
            }
            .frame(maxWidth: readerWidth, alignment: .leading)
            .padding(.horizontal, NLMetrics.margin)
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
        }
        .background(NLBackground())
        #if os(tvOS)
        .overlay(alignment: .bottomTrailing) {
            if let focusedParagraph {
                Text("Paragraph \(focusedParagraph + 1) of \(paragraphs.count)")
                    .font(NLFont.caption)
                    .monospacedDigit()
                    .foregroundStyle(NL.textTertiary)
                    .padding(40)
            }
        }
        #else
        .navigationTitle(issue.title(for: store.lang))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if let url = issue.htmlURL {
                ToolbarItem { ShareLink(item: url) }
            }
        }
        #endif
    }

    private var readerWidth: CGFloat {
        #if os(tvOS)
        1100
        #elseif os(iOS)
        640
        #else
        680
        #endif
    }
}

private struct ReaderParagraph: View {
    let text: String
    let focused: Bool

    var body: some View {
        // Short lines without a full stop are section and story headings.
        let isHeading = text.count < 110 && !text.contains("\n") && !text.hasSuffix(".")
        Text(text)
            .font(isHeading ? NLFont.title.weight(.semibold) : NLFont.reader)
            .foregroundStyle(isHeading ? NL.textPrimary : NL.textSecondary)
            .lineSpacing(isHeading ? 2 : 7)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, isHeading ? 16 : 10)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(focused ? NL.hairline : .clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .animation(.smooth(duration: 0.2), value: focused)
    }
}
