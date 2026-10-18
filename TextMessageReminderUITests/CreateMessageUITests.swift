import XCTest

final class CreateMessageUITests: XCTestCase {

    private let contactName = "David Taylor"
    private let contactHandle = "555-610-6679"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitesting"]
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) {
            allow.tap()
        }
        return app
    }

    func testCreateMessageFromContactAppearsInList() {
        let app = launchApp()
        let message = "Hey David, checking in!"

        app.buttons["Schedule Message"].firstMatch.tap()

        let editor = app.navigationBars["New Message"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "The editor form should open.")

        app.buttons["Choose a contact"].firstMatch.tap()
        XCTAssertTrue(
            app.pickerNavigationBar.waitForExistence(timeout: 10),
            "The contact picker should present."
        )

        app.staticTexts[contactName].firstMatch.tap()

        XCTAssertTrue(
            editor.waitForExistence(timeout: 5),
            "Selecting a contact must not dismiss the editor."
        )
        XCTAssertTrue(
            app.staticTexts[contactHandle].waitForExistence(timeout: 5),
            "The chosen handle should populate the form."
        )

        let messageField = app.textViews.firstMatch
        XCTAssertTrue(messageField.waitForExistence(timeout: 5), "Message field should exist.")
        messageField.tap()
        messageField.typeText(message)

        let save = editor.buttons["Save"]
        XCTAssertTrue(save.isEnabled, "Save should enable once contact and message are set.")
        save.tap()

        XCTAssertTrue(
            app.navigationBars["Messages"].waitForExistence(timeout: 5),
            "Saving should return to the list."
        )
        XCTAssertTrue(
            app.staticTexts[message].waitForExistence(timeout: 5),
            "The saved message should appear in the list."
        )
        // The row puts the contact and the cadence on one summary line, so match
        // on the contact appearing within it rather than as a label of its own.
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", contactName))
                .firstMatch.waitForExistence(timeout: 5),
            "The message row should name the contact."
        )
    }

    func testSecondMessageAlsoAppearsInList() {
        let app = launchApp()

        add(to: app, contact: contactName, message: "First message")
        XCTAssertTrue(
            app.staticTexts["First message"].waitForExistence(timeout: 5),
            "The first message should appear."
        )

        add(to: app, contact: "Kate Bell", message: "Second message")
        XCTAssertTrue(
            app.staticTexts["Second message"].waitForExistence(timeout: 5),
            "The second message should appear too."
        )
        XCTAssertTrue(app.staticTexts["First message"].exists, "The first should still be listed.")
    }

    func testEditorExplainsWhySaveIsDisabled() {
        let app = launchApp()

        app.buttons["Schedule Message"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["New Message"].waitForExistence(timeout: 5))

        XCTAssertTrue(
            app.staticTexts["Choose a contact and write a message to save it."]
                .waitForExistence(timeout: 5),
            "The form should say what's still missing."
        )
    }

    private func add(to app: XCUIApplication, contact: String, message: String) {
        app.buttons["Schedule Message"].firstMatch.tap()

        let editor = app.navigationBars["New Message"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "The editor should open.")

        app.buttons["Choose a contact"].firstMatch.tap()
        XCTAssertTrue(
            app.pickerNavigationBar.waitForExistence(timeout: 10),
            "The contact picker should present."
        )
        app.staticTexts[contact].firstMatch.tap()

        let messageField = app.textViews.firstMatch
        XCTAssertTrue(messageField.waitForExistence(timeout: 5))
        messageField.tap()
        messageField.typeText(message)

        XCTAssertTrue(editor.buttons["Save"].isEnabled, "Save should enable once both are set.")
        editor.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Messages"].waitForExistence(timeout: 5))
    }
}
