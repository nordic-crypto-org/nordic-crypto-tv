import SwiftUI
#if os(iOS)
import BackgroundTasks
import UserNotifications
#elseif os(macOS) || os(visionOS)
import UserNotifications
#endif

@main
struct NordicCryptoApp: App {
    #if os(iOS) || os(visionOS)
    @UIApplicationDelegateAdaptor private var delegate: AppDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    #endif
    #if os(iOS) || os(macOS) || os(visionOS)
    @Environment(\.scenePhase) private var scenePhase
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, AppLanguage.locale)
                #if os(tvOS)
                .preferredColorScheme(.dark)
                // A news screen meant to stay on: never hand over to the screensaver.
                .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
                #elseif os(macOS)
                .frame(minWidth: 900, minHeight: 620)
                #endif
        }
        #if os(visionOS)
        .defaultSize(width: 1280, height: 820)
        #elseif os(macOS)
        .defaultSize(width: 1440, height: 872)
        #endif
        #if os(iOS) || os(macOS) || os(visionOS)
        .onChange(of: scenePhase) { _, phase in
            NewsAlerts.shared.foreground = phase == .active
            #if os(iOS)
            if phase == .background { AppDelegate.scheduleRefresh() }
            #endif
        }
        #endif
        #if os(iOS)
        .backgroundTask(.appRefresh(AppDelegate.refreshTask)) {
            await AppDelegate.scheduleRefreshAsync()
            await NewsAlerts.check()
        }
        #endif

        #if os(visionOS)
        WindowGroup(id: "newsreel", for: URL.self) { $url in
            if let url { NewsreelWindow(url: url) }
        }
        .defaultSize(width: 1280, height: 720)
        #endif

        #if os(macOS)
        Window("Contact us", id: "contact") {
            ContactView()
                .frame(minWidth: 480, minHeight: 520)
        }
        .defaultSize(width: 520, height: 640)
        Settings {
            TabView {
                AlertSettingsView()
                    .tabItem { Label("Notifications", systemImage: "bell") }
                ContactView()
                    .tabItem { Label("Contact us", systemImage: "envelope") }
            }
            .frame(width: 520, height: 560)
        }
        if !SnapshotMode.isOn {
            MenuBarExtra("Nordic Crypto", systemImage: "sparkle") {
                MenuBarHeadlines()
            }
        }
        #endif
    }
}

#if os(iOS) || os(visionOS)
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
        if SnapshotMode.isOn { return true }
        #if os(iOS)
        Self.scheduleRefresh()
        #endif
        // Re-registers with the push server (or tells it to forget this device).
        PushRegistration.shared.refresh()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushRegistration.shared.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushRegistration.shared.didFailToRegister()
    }
}
#endif

#if os(iOS)
extension AppDelegate {
    static let refreshTask = "no.cryptonordic.tv.refresh"

    /// Asks iOS to wake the app for a news check in about 15 minutes.
    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTask)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func scheduleRefreshAsync() async { scheduleRefresh() }
}
#elseif os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var poller: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
        if SnapshotMode.isOn { return }
        PushRegistration.shared.refresh()
        // Keeps checking while the app runs, also with every window closed.
        poller = Task.detached {
            while !Task.isCancelled {
                await NewsAlerts.check()
                try? await Task.sleep(for: .seconds(15 * 60))
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushRegistration.shared.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushRegistration.shared.didFailToRegister()
    }
}

/// The menu bar menu: the latest headlines and a way back to the window.
private struct MenuBarHeadlines: View {
    @State private var store = FeedStore()
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ForEach(store.news.prefix(8)) { item in
            Button {
                if let url = item.url { NSWorkspace.shared.open(url) }
            } label: {
                Text(verbatim: "\(item.country ?? "") · \(item.headline(for: store.lang))")
            }
        }
        Divider()
        Button("Contact us") { openWindow(id: "contact") }
        SettingsLink { Text("Notifications…") }
        Button("Quit Nordic Crypto") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
#endif
