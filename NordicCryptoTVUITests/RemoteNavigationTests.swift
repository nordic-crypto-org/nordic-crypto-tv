import XCTest

/// Apple TV opens on the information screen with the tab bar hidden. Up
/// shows the tab bar (Today, Badge, Contact us), Play/Pause switches the radio.
final class SignageRemoteTests: XCTestCase {
    private let remote = XCUIRemote.shared
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-NCBadgeStub"]
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
        XCTAssertTrue(tabs.buttons["Nordic Shield NFT"].hasFocus)
        XCTAssertTrue(app.staticTexts["badge-screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["badge-count"].label.hasPrefix("42 /"))
        XCTAssertTrue(app.descendants(matching: .any)["badge-qr"].waitForExistence(timeout: 5))
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

    /// The calendar shows at most five rows, all inside its panel, in every language.
    func testAgendaRowsFitThePanel() {
        for lang in ["en", "nb", "de"] {
            app.terminate()
            app.launchArguments = ["-AppleLanguages", "(\(lang))", "-NCBadgeStub", "-NCFreeze"]
            app.launch()
            let agenda = app.descendants(matching: .any)["agenda"]
            XCTAssertTrue(agenda.waitForExistence(timeout: 10), lang)
            sleep(2)
            attach("agenda-\(lang)")
            let rows = agenda.descendants(matching: .any).matching(identifier: "agenda-row").allElementsBoundByIndex
            XCTAssertFalse(rows.isEmpty, lang)
            XCTAssertLessThanOrEqual(rows.count, 5, lang)
            for row in rows {
                XCTAssertTrue(agenda.frame.contains(row.frame), "\(lang): \(row.label) \(row.frame) outside \(agenda.frame)")
            }
        }
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
        XCTAssertEqual(before, "Off", "the radio never starts by itself")
        remote.press(.playPause)
        sleep(1)
        XCTAssertNotEqual(radio.value as? String, before)
        remote.press(.playPause)
        sleep(1)
        XCTAssertEqual(radio.value as? String, before, "a second press restores the radio")
    }

    func testSelectKeepsRadioNorgeUntilFiveQuickPresses() {
        let radio = app.descendants(matching: .any)["radio"]
        XCTAssertTrue(radio.waitForExistence(timeout: 10))
        XCTAssertTrue(radio.label.hasPrefix("Radio Norge"))
        remote.press(.select)
        sleep(2)
        XCTAssertTrue(radio.label.hasPrefix("Radio Norge"))
        for _ in 0..<5 { remote.press(.select) }
        sleep(1)
        XCTAssertFalse(radio.label.hasPrefix("Radio Norge"))
        XCTAssertEqual(radio.value as? String, "Off", "changing station never starts the radio")
    }
}
