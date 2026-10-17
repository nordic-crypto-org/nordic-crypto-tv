#if os(tvOS)
import XCTest
@testable import Nordic_Crypto

final class RadioStationsTests: XCTestCase {
    func testStations() {
        let stations = Radio.stations
        XCTAssertEqual(stations.map(\.name), ["Radio Norge", "Techno Underground | Fluxmusic", "Berlin Beach House Radio"])
        XCTAssertTrue(stations.allSatisfy { $0.stream.scheme == "https" && $0.homepage.scheme == "https" })
        XCTAssertEqual(Set(stations.map(\.stream)).count, stations.count)
    }
}
#endif
