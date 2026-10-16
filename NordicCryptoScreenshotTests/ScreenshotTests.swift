import XCTest

/// Captures one stable screen per launch argument. The App Store media
/// workflow sets NC_SHOT_DIR and NC_SCREENS and runs this on each required
/// simulator (and on the Mac). Content comes from the bundled snapshot
/// because every launch passes `-NCSnapshot`.
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testCapture() throws {
        let screens = (ProcessInfo.processInfo.environment["NC_SCREENS"] ?? "today,story,events,countries,newsletter")
            .split(separator: ",")
            .map { String($0) }
        let lang = ProcessInfo.processInfo.environment["NC_LANG"] ?? "en"
        let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["NC_SHOT_DIR"] ?? NSTemporaryDirectory(),
                      isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        for (index, name) in screens.enumerated() {
            let app = XCUIApplication()
            app.launchArguments = [
                "-NCSnapshot", "-NCFreeze",
                "-AppleLanguages", "(\(lang))",
                "-AppleLocale", "en_GB",
                "-AppleInterfaceStyle", "Dark",
            ]
            if name == "story" {
                app.launchArguments += ["-NCOpen", "story"]
            } else if name != "dashboard" {
                app.launchArguments += ["-NCScreen", name]
            }
            app.launch()
            settle(app)

            let shot: XCUIScreenshot
            #if os(macOS)
            let window = app.windows.firstMatch
            XCTAssertTrue(window.waitForExistence(timeout: 20), "Mac window did not appear for \(name)")
            shot = window.screenshot()
            #else
            shot = XCUIScreen.main.screenshot()
            #endif
            let file = dir.appendingPathComponent(String(format: "%02d-%@.png", index + 1, name))
            try shot.pngRepresentation.write(to: file)
            app.terminate()
        }
    }

    private func settle(_ app: XCUIApplication) {
        #if os(tvOS)
        XCTAssertTrue(app.descendants(matching: .any)["radio"].waitForExistence(timeout: 30))
        #else
        XCTAssertTrue(app.staticTexts.firstMatch.waitForExistence(timeout: 30), "no content appeared")
        #endif
        Thread.sleep(forTimeInterval: 2)
    }
}
