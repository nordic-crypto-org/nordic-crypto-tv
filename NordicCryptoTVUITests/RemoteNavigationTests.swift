import XCTest

/// Apple TV opens on the information screen with the tab bar hidden. Up
/// shows the tab bar (Today, Badge, Contact us), Play/Pause switches the radio.
final class SignageRemoteTests: XCTestCase {
    private let remote = XCUIRemote.shared
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)"]
        app.launch()
    }

    func testTabBarReachesBadgeAndContactUs() {
        XCTAssertTrue(app.descendants(matching: .any)["radio"].waitForExistence(timeout: 10))
        attach("signage")
        remote.press(.up)
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 5))
        XCTAssertTrue(tabs.buttons["Today"].hasFocus)
        attach("tab-bar")

        remote.press(.right)
        XCTAssertTrue(tabs.buttons["Badge"].hasFocus)
        XCTAssertTrue(app.staticTexts["badge-screen"].waitForExistence(timeout: 5))
        sleep(3)
        attach("badge")

        remote.press(.right)
        XCTAssertTrue(tabs.buttons["Contact us"].hasFocus)
        XCTAssertTrue(app.staticTexts["publisher-company"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["publisher-company"].label, "jQrgenCorp")
        XCTAssertEqual(app.staticTexts["publisher-org"].label, "org.nr. 919 057 343")
        shows("contact-email", "jqrgen@nordiccrypto.no")
        shows("contact-website", "https://nordiccrypto.no")
        shows("contact-page", "https://nordiccrypto.no/contact/")
    }

    private func shows(_ identifier: String, _ text: String) {
        let element = app.buttons[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: 5), identifier)
        let shown = "\(element.label) \(element.value as? String ?? "")"
        XCTAssertTrue(shown.contains(text), "\(identifier) showed \(shown)")
    }

    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
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
