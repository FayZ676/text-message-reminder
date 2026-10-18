import XCTest

final class MessageEditorUITests: XCTestCase {

    private let permissionPromptSteps = 3

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        dismissPermissionPromptsIfPresent()
        return app
    }

    private func dismissPermissionPromptsIfPresent() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let shareAll = springboard.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Share All'")
        ).firstMatch

        for _ in 0..<permissionPromptSteps {
            let candidates = ["Allow", "Continue"].map { springboard.buttons[$0] } + [shareAll]

            guard let button = candidates.first(where: { $0.waitForExistence(timeout: 3) })
            else { return }

            button.tap()
        }
    }

    func testEditorStaysOpenAfterDismissingContactPicker() {
        let app = launchApp()

        app.buttons["Schedule Message"].firstMatch.tap()

        let editor = app.navigationBars["New Message"]
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

        app.buttons["Schedule Message"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["New Message"].waitForExistence(timeout: 5))

        for attempt in 1...2 {
            app.buttons["Choose a contact"].firstMatch.tap()

            let pickerBar = app.pickerNavigationBar
            XCTAssertTrue(
                pickerBar.waitForExistence(timeout: 10),
                "The contact picker should present on attempt \(attempt)."
            )

            pickerBar.buttons["Cancel"].tap()
            XCTAssertTrue(
                app.navigationBars["New Message"].waitForExistence(timeout: 5),
                "The editor should still be open after attempt \(attempt)."
            )
        }
    }

    func testSaveIsDisabledWithoutContactAndMessage() {
        let app = launchApp()

        app.buttons["Schedule Message"].firstMatch.tap()

        let editor = app.navigationBars["New Message"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "The editor form should open.")

        XCTAssertFalse(
            editor.buttons["Save"].isEnabled,
            "Save should be disabled with no contact and no message."
        )
    }
}
