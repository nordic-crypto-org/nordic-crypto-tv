import SwiftUI

enum AppTab: String, Hashable, CaseIterable {
    case today, countries, events, newsletter, badge, contact
}

enum Route: Hashable {
    case story(NewsItem)
    case event(EventItem)
    case reader(NewsletterIssue)
    case country(String)
}

@MainActor
@Observable
final class Router {
    var tab: AppTab = .today
    var paths: [AppTab: [Route]] = [:]
    /// Apple TV plays the newsreel full screen.
    var newsreel: Newsreel?

    func path(_ tab: AppTab) -> Binding<[Route]> {
        Binding(get: { self.paths[tab] ?? [] }, set: { self.paths[tab] = $0 })
    }

    func open(_ route: Route) {
        paths[tab, default: []].append(route)
    }
}

struct RootView: View {
    @State private var store = FeedStore()
    @State private var router = Router()
    #if os(tvOS)
    @State private var radio = Radio()
    #endif

    var body: some View {
        #if os(tvOS)
        // Apple TV is an information screen: no tabs, nothing to navigate.
        SignageView()
            .environment(store)
            .environment(radio)
            .task { await store.run() }
            .onAppear { radio.start() }
        #else
        tabs
        #endif
    }

    #if !os(tvOS)
    private var tabs: some View {
        @Bindable var router = router
        return TabView(selection: $router.tab) {
            Tab("Today", systemImage: "sun.horizon", value: AppTab.today) {
                stack(.today) { TodayView() }
            }
            Tab("Countries", systemImage: "map", value: AppTab.countries) {
                stack(.countries) { CountriesView() }
            }
            Tab("Events", systemImage: "calendar", value: AppTab.events) {
                stack(.events) { EventsView() }
            }
            Tab("Newsletter", systemImage: "envelope.open", value: AppTab.newsletter) {
                stack(.newsletter) { NewsletterView() }
            }
            Tab("Badge", systemImage: "checkmark.shield", value: AppTab.badge) {
                NavigationStack { BadgeView() }
            }
            Tab("Contact us", systemImage: "envelope", value: AppTab.contact) {
                NavigationStack { ContactView() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(NL.accent)
        .environment(store)
        .environment(router)
        .task { await store.run() }
        .onReceive(NotificationCenter.default.publisher(for: .openStory)) { note in
            guard let id = note.object as? String, let item = store.news.first(where: { $0.id == id }) else { return }
            router.tab = .today
            router.paths[.today] = [.story(item)]
        }
        #if DEBUG
        .onAppear(perform: applyScreenshotArguments)
        #endif
    }
    #endif

    private func stack<Content: View>(_ tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack(path: router.path(tab)) {
            content()
                .navigationDestination(for: Route.self) { route in
                    RouteView(route: route)
                }
        }
    }
}

private struct RouteView: View {
    let route: Route

    var body: some View {
        switch route {
        case .story(let item): StoryDetailView(item: item)
        case .event(let event): EventDetailView(event: event)
        case .reader(let issue): ReaderView(issue: issue)
        case .country(let code): CountryNewsView(country: Country(rawValue: code) ?? .no)
        }
    }
}

/// Polar-night backdrop with a faint aurora glow at the top.
struct NLBackground: View {
    var body: some View {
        #if os(visionOS)
        Color.clear
        #else
        ZStack(alignment: .top) {
            NL.bg
            LinearGradient(colors: [NL.bgAuroraTop, NL.bg], startPoint: .top, endPoint: .bottom)
                .frame(height: 420)
            RadialGradient(colors: [NL.accent.opacity(0.10), .clear], center: .topLeading, startRadius: 0, endRadius: 700)
            RadialGradient(colors: [NL.accent2.opacity(0.10), .clear], center: .topTrailing, startRadius: 0, endRadius: 600)
        }
        .ignoresSafeArea()
        #endif
    }
}

extension Newsreel: Identifiable {
    var id: String { playableURL?.absoluteString ?? "" }
}

#if DEBUG && !os(tvOS)
extension RootView {
    /// `-NCScreen today|countries|events|newsletter` and
    /// `-NCOpen story|event|reader|newsreel`, for screenshots and UI tests.
    private func applyScreenshotArguments() {
        let args = ProcessInfo.processInfo.arguments
        func value(_ flag: String) -> String? {
            args.firstIndex(of: flag).flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
        }
        let aliases = ["top": "today", "nordics": "countries", "brief": "newsletter"]
        if let name = value("-NCScreen"), let tab = AppTab(rawValue: aliases[name] ?? name) {
            router.tab = tab
        }
        switch value("-NCOpen") {
        case "story": store.news.first.map { router.open(.story($0)) }
        case "event": store.upcomingEvents.first.map { router.open(.event($0)) }
        case "reader": store.issues.first.flatMap { store.issue($0.id) }.map { router.open(.reader($0)) }
        default: break
        }
    }
}
#endif
