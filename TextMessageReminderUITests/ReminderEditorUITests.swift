import XCTest

final class ReminderEditorUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        dismissNotificationPromptIfPresent()
        return app
    }

    private func dismissNotificationPromptIfPresent() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) {
            allow.tap()
        }
    }

    func testEditorStaysOpenAfterDismissingContactPicker() {
        let app = launchApp()

        app.buttons["Add Reminder"].firstMatch.tap()

        let editor = app.navigationBars["New Reminder"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "The editor form should open.")

        app.buttons["Choose a contact"].firstMatch.tap()

        let pickerBar = app.pickerNavigationBar
        XCTAssertTrue(
            pickerBar.waitForExistence(timeout: 10),
            "The contact picker should present."
        )

        pickerBar.buttons["Cancel"].tap()

        XCTAssertTrue(
            editor.waitForExistence(timeout: 5),
            "Dismissing the contact picker must leave the editor form open."
        )
    }

    func testContactPickerCanBeReopenedAfterCancelling() {
        let app = launchApp()

        app.buttons["Add Reminder"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["New Reminder"].waitForExistence(timeout: 5))

        for attempt in 1...2 {
            app.buttons["Choose a contact"].firstMatch.tap()

            let pickerBar = app.pickerNavigationBar
            XCTAssertTrue(
                pickerBar.waitForExistence(timeout: 10),
                "The contact picker should present on attempt \(attempt)."
            )

            pickerBar.buttons["Cancel"].tap()
            XCTAssertTrue(
                app.navigationBars["New Reminder"].waitForExistence(timeout: 5),
                "The editor should still be open after attempt \(attempt)."
            )
        }
    }

    func testSaveIsDisabledWithoutContactAndMessage() {
        let app = launchApp()

        app.buttons["Add Reminder"].firstMatch.tap()

        let editor = app.navigationBars["New Reminder"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "The editor form should open.")

        XCTAssertFalse(
            editor.buttons["Save"].isEnabled,
            "Save should be disabled with no contact and no message."
        )
    }
}
