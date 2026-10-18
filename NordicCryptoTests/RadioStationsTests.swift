#if os(tvOS)
import XCTest
@testable import Nordic_Crypto

@MainActor
final class RadioStationsTests: XCTestCase {
    func testStations() {
        let stations = Radio.stations
        XCTAssertEqual(stations.map(\.name), ["Radio Norge", "Techno Underground | Fluxmusic", "Berlin Beach House Radio"])
        XCTAssertTrue(stations.allSatisfy { $0.stream.scheme == "https" && $0.homepage.scheme == "https" })
        XCTAssertEqual(Set(stations.map(\.stream)).count, stations.count)
    }

    func testRadioNorgeUnlessFiveQuickPresses() {
        let defaults = UserDefaults.standard
        let wasOn = defaults.object(forKey: "radio.on")
        defaults.set("Berlin Beach House Radio", forKey: "radio.station")
        defer {
            defaults.removeObject(forKey: "radio.station")
            defaults.set(wasOn, forKey: "radio.on")
        }
        let radio = Radio()
        XCTAssertEqual(radio.station.name, "Radio Norge")
        let start = Date()
        for i in 0..<4 { radio.select(at: start + Double(i)) }
        radio.select(at: start + 10)
        XCTAssertEqual(radio.station.name, "Radio Norge")
        var names: [String] = []
        for round in 0..<3 {
            for i in 0..<5 { radio.select(at: start + 20 + Double(round * 10) + Double(i) * 0.5) }
            names.append(radio.station.name)
        }
        XCTAssertEqual(names, ["Techno Underground | Fluxmusic", "Berlin Beach House Radio", "Radio Norge"])
    }
}
#endif
