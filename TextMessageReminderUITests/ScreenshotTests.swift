import XCTest

/// Captures the App Store screenshots from seeded data. Skipped unless the
/// runner is given somewhere to put them:
///
///     TEST_RUNNER_SCREENSHOT_DIR=/path/to/dir xcodebuild test ... \
///       -only-testing:TextMessageReminderUITests/ScreenshotTests
final class ScreenshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testCaptureAppStoreScreenshots() throws {
        guard let directory = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else {
            throw XCTSkip("Set TEST_RUNNER_SCREENSHOT_DIR to capture screenshots.")
        }
        let output = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        let app = XCUIApplication()
        app.launchArguments = ["-uitesting", "-screenshots"]
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) {
            allow.tap()
        }

        func capture(_ name: String) throws {
            sleep(1)
            let data = XCUIScreen.main.screenshot().pngRepresentation
            try data.write(to: output.appendingPathComponent("\(name).png"))
        }

        XCTAssertTrue(app.staticTexts["Good morning"].waitForExistence(timeout: 10))
        try capture("1-messages")

        app.staticTexts["Birthdays"].tap()
        XCTAssertTrue(app.navigationBars["Birthdays"].waitForExistence(timeout: 5))
        try capture("2-birthdays")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.staticTexts["Check in with Jordan"].tap()
        XCTAssertTrue(app.navigationBars["Edit Message"].waitForExistence(timeout: 5))
        try capture("3-editor")
    }
}
