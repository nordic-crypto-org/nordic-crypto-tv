#if os(tvOS)
import AVFoundation
import Observation

/// Radio Norge in the background of the Apple TV app. Off at launch; it plays
/// only after the viewer presses Play. The other stations are an easter egg (see `select`).
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
    private(set) var isOn = false
    private(set) var station = Radio.stations[0]
    private(set) var isPlaying = false
    /// True while something else (the newsreel) has the sound.
    private var yielded = false
    private var player: AVPlayer?
    private var watchdog: Task<Void, Never>?
    private var presses: [Date] = []

    func start() {
        watchdog?.cancel()
        // Live streams drop; reconnect a failed stream, but never resume one paused
        // by the system (interruption, Control Center, AirPlay).
        watchdog = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard let self else { return }
                guard self.isOn, !self.yielded, let player = self.player else { continue }
                if player.currentItem?.status == .failed || player.error != nil {
                    self.play()
                } else if player.timeControlStatus == .paused && player.rate == 0 {
                    self.stop()
                    self.isOn = false
                }
            }
        }
    }

    func toggle() {
        isOn.toggle()
        if isOn && !yielded { play() } else { stop() }
    }

    /// Select on the remote: five quick presses switch to the next station.
    func select(at now: Date = .now) {
        if let last = presses.last, now.timeIntervalSince(last) > 1.5 { presses = [] }
        presses.append(now)
        guard presses.count == 5 else { return }
        presses = []
        next()
    }

    /// Switch to the next station; it plays only if the radio is on.
    private func next() {
        let index = Self.stations.firstIndex(of: station) ?? 0
        station = Self.stations[(index + 1) % Self.stations.count]
        if isOn && !yielded { play() }
    }

    /// Pause for other audio, e.g. while the newsreel plays.
    func yield(_ value: Bool) {
        yielded = value
        if value { stop(); isOn = false }
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
