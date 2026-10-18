#if os(tvOS)
import AVFoundation
import Observation

/// Radio in the background of the Apple TV app, Radio Norge by default. On by
/// default; the viewer's choice of station and on/off is remembered.
@MainActor
@Observable
final class Radio {
    struct Station: Equatable {
        let name: String
        let stream: URL
        let homepage: URL
    }

    static let stations = [
        Station(name: "Radio Norge",
                stream: URL(string: "https://live-bauerno.sharp-stream.com/radionorge_no_mp3")!,
                homepage: URL(string: "https://www.radionorge.no/")!),
        Station(name: "Techno Underground | Fluxmusic",
                stream: URL(string: "https://streams.fluxfm.de/technoug/mp3-128")!,
                homepage: URL(string: "https://www.fluxfm.de/")!),
        Station(name: "Berlin Beach House Radio",
                stream: URL(string: "https://streams.fluxfm.de/bbeachhouse/mp3-128")!,
                homepage: URL(string: "https://www.fluxfm.de/")!),
    ]
    private static let key = "radio.on"
    private static let stationKey = "radio.station"

    private(set) var isOn: Bool
    private(set) var station: Station
    private(set) var isPlaying = false
    /// True while something else (the newsreel) has the sound.
    private var yielded = false
    private var player: AVPlayer?
    private var watchdog: Task<Void, Never>?

    init() {
        isOn = UserDefaults.standard.object(forKey: Self.key) as? Bool ?? true
        let name = UserDefaults.standard.string(forKey: Self.stationKey)
        station = Self.stations.first { $0.name == name } ?? Self.stations[0]
    }

    func start() {
        if isOn && !yielded { play() }
        watchdog?.cancel()
        // Live streams drop; reconnect whenever the radio should be playing but is not.
        watchdog = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard let self else { return }
                if self.isOn && !self.yielded && self.player?.timeControlStatus != .playing { self.play() }
            }
        }
    }

    func toggle() {
        isOn.toggle()
        UserDefaults.standard.set(isOn, forKey: Self.key)
        if isOn && !yielded { play() } else { stop() }
    }

    /// Switch to the next station and turn the radio on.
    func next() {
        let index = Self.stations.firstIndex(of: station) ?? 0
        station = Self.stations[(index + 1) % Self.stations.count]
        UserDefaults.standard.set(station.name, forKey: Self.stationKey)
        isOn = true
        UserDefaults.standard.set(true, forKey: Self.key)
        if !yielded { play() }
    }

    /// Pause for other audio, e.g. while the newsreel plays.
    func yield(_ value: Bool) {
        yielded = value
        if value { stop() } else if isOn { play() }
    }

    private func play() {
        // A fresh item each time, so playback rejoins the live edge.
        let player = AVPlayer(url: station.stream)
        player.automaticallyWaitsToMinimizeStalling = true
        self.player?.pause()
        self.player = player
        isPlaying = true
        Task { [weak self] in
            // Long-form audio follows the speakers picked in Control Center (AirPlay).
            // Activating the session can block; keep it off the main thread.
            await Task.detached(priority: .userInitiated) {
                let session = AVAudioSession.sharedInstance()
                try? session.setCategory(.playback, mode: .default, policy: .longFormAudio)
                try? session.setActive(true)
            }.value
            guard self?.player === player else { return }
            player.play()
        }
    }

    private func stop() {
        player?.pause()
        player = nil
        isPlaying = false
    }
}
#endif
