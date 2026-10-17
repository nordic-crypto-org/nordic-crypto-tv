import XCTest

/// Apple TV is an information screen. Play/Pause switches the radio, and
/// Contact us opens the publisher's contact details.
final class SignageRemoteTests: XCTestCase {
    private let remote = XCUIRemote.shared
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)"]
        app.launch()
    }

    func testContactUsOpensFromTheMainScreen() {
        XCTAssertTrue(app.descendants(matching: .any)["radio"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.tabBars.count, 0, "no tab bar on the information screen")
        let contact = app.buttons["contact-us"]
        XCTAssertTrue(contact.waitForExistence(timeout: 5))
        XCTAssertEqual(contact.label, "Contact us")
        contact.tap()
        XCTAssertTrue(app.staticTexts["publisher-company"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["publisher-company"].label, "jQrgenCorp")
        XCTAssertEqual(app.staticTexts["publisher-org"].label, "org.nr. 919 057 343")
        shows("contact-email", "jqrgen@nordiccrypto.no")
        shows("contact-website", "https://nordiccrypto.no")
        shows("contact-page", "https://nordiccrypto.no/contact/")
        remote.press(.menu)
        XCTAssertTrue(contact.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["publisher-company"].exists)
    }

    func testBadgeOpensFromTheMainScreen() {
        let badge = app.buttons["badge"]
        XCTAssertTrue(badge.waitForExistence(timeout: 10))
        badge.tap()
        XCTAssertTrue(app.staticTexts["badge-screen"].waitForExistence(timeout: 5))
        remote.press(.menu)
        XCTAssertTrue(badge.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["badge-screen"].exists)
    }

    private func shows(_ identifier: String, _ text: String) {
        let element = app.buttons[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: 5), identifier)
        let shown = "\(element.label) \(element.value as? String ?? "")"
        XCTAssertTrue(shown.contains(text), "\(identifier) showed \(shown)")
    }

    func testPlayPauseSwitchesTheRadio() {
        let radio = app.descendants(matching: .any)["radio"]
        XCTAssertTrue(radio.waitForExistence(timeout: 10))
        let before = radio.value as? String
        remote.press(.playPause)
        sleep(1)
        XCTAssertNotEqual(radio.value as? String, before)
        remote.press(.playPause)
        sleep(1)
        XCTAssertEqual(radio.value as? String, before, "a second press restores the radio")
    }
}
