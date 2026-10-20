import Foundation

/// `-NCSnapshot` keeps screenshots on the bundled fixture: no network refresh,
/// no shuffled spotlight, and clocks stuck on the snapshot's generated date.
enum SnapshotMode {
    static var isOn: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-NCSnapshot")
        #else
        false
        #endif
    }

    /// `generated_at` in NordicCrypto/Resources/Snapshot/news.json.
    static let frozenDate = Date(timeIntervalSince1970: 1_791_240_302)
}
