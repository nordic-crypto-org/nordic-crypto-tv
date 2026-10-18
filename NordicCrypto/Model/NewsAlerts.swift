import Foundation
#if os(iOS) || os(macOS) || os(visionOS)
import Observation
import UserNotifications

/// Notifications for new stories, filtered by country. When the push server
/// has this device (`PushRegistration`), new stories arrive as remote
/// notifications and this class only remembers what it has seen. Otherwise it
/// is the fallback: the app checks the public news feed itself and posts local
/// notifications for stories it has not seen before.
@MainActor
@Observable
final class NewsAlerts {
    static let shared = NewsAlerts()

    private enum Key {
        static let enabled = "alerts.enabled"
        static let countries = "alerts.countries"
        static let seen = "alerts.seen"
    }

    private(set) var enabled: Bool
    private(set) var countries: Set<String>
    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    /// True while the app is on screen; then nothing is announced.
    var foreground = false

    private init() {
        let d = UserDefaults.standard
        enabled = d.bool(forKey: Key.enabled)
        countries = Set(d.stringArray(forKey: Key.countries) ?? Country.allCases.map(\.rawValue))
    }

    func refreshAuthorization() async {
        authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func setEnabled(_ on: Bool) async {
        if on {
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            await refreshAuthorization()
            enabled = granted
        } else {
            enabled = false
        }
        UserDefaults.standard.set(enabled, forKey: Key.enabled)
        PushRegistration.shared.refresh()
    }

    func toggle(_ country: Country) {
        if countries.contains(country.rawValue) { countries.remove(country.rawValue) } else { countries.insert(country.rawValue) }
        UserDefaults.standard.set(Array(countries), forKey: Key.countries)
        PushRegistration.shared.settingsChanged()
    }

    /// Announces stories not seen before from the chosen countries, then
    /// remembers everything in `news` as seen. The first run only remembers.
    func process(_ news: [NewsItem], lang: String) {
        let d = UserDefaults.standard
        let seenList = d.stringArray(forKey: Key.seen)
        var seen = Set(seenList ?? [])
        let fresh = news.filter { !seen.contains($0.id) }
        defer {
            for item in news { seen.insert(item.id) }
            // Keep the list bounded: the feed holds well under 500 stories.
            let current = Set(news.map(\.id))
            let trimmed = seen.count > 500 ? Array(current) : Array(seen)
            d.set(trimmed, forKey: Key.seen)
        }
        // The push server announces these when it has this device.
        guard seenList != nil, enabled, !foreground, !PushRegistration.shared.active else { return }
        let wanted = fresh.filter { countries.contains($0.country ?? "") }
        guard !wanted.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        if wanted.count <= 3 {
            for item in wanted {
                let content = UNMutableNotificationContent()
                let country = Country(rawValue: item.country ?? "")?.name
                content.title = [item.sourceName, country].compactMap { $0 }.joined(separator: " · ")
                content.body = item.headline(for: lang)
                content.threadIdentifier = item.country ?? "news"
                content.userInfo = ["story": item.id]
                content.sound = .default
                center.add(UNNotificationRequest(identifier: "story-" + item.id, content: content, trigger: nil))
            }
        } else {
            let content = UNMutableNotificationContent()
            content.title = "Nordic Crypto"
            content.body = String(localized: "\(wanted.count) new stories", bundle: AppLanguage.bundle) + ": " + wanted.prefix(2).map { $0.headline(for: lang) }.joined(separator: " · ")
            content.userInfo = ["story": wanted[0].id]
            content.sound = .default
            center.add(UNNotificationRequest(identifier: "batch-" + wanted[0].id, content: content, trigger: nil))
        }
    }

    /// One background check: fetch the feed and announce what is new.
    nonisolated static func check() async {
        guard let feed = try? await APIClient().fetch(NewsFeed.self, path: "news.json") else { return }
        await MainActor.run { shared.process(feed.items, lang: AppLanguage.current) }
    }
}

/// Opens the tapped story and shows banners while the app is open on Mac.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if let id = response.notification.request.content.userInfo["story"] as? String {
            await MainActor.run { NotificationCenter.default.post(name: .openStory, object: id) }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
#endif

extension Notification.Name {
    /// Posted with the story id when the reader taps a story notification.
    static let openStory = Notification.Name("NordicCrypto.openStory")
}
