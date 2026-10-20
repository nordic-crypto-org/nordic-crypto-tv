import XCTest
@testable import Nordic_Crypto

final class FeatureFlagsTests: XCTestCase {
    func testNFTDefaultsOff() {
        XCTAssertFalse(FeatureFlags.nftIOS(from: Data("{}".utf8)))
        XCTAssertFalse(FeatureFlags.nftIOS(from: Data("not json".utf8)))
        XCTAssertFalse(FeatureFlags.nftIOS(from: Data(#"{"nft":{"ios":false}}"#.utf8)))
        XCTAssertTrue(FeatureFlags.nftIOS(from: Data(#"{"nft":{"ios":true}}"#.utf8)))
    }
}
