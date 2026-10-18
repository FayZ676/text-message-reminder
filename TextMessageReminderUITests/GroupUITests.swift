import XCTest

final class GroupUITests: XCTestCase {

    private let groupName = "Birthdays"
    private let contactName = "David Taylor"

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

    func testCreatedGroupAppearsOnTheRootScreen() {
        let app = launchApp()

        addGroup(to: app)

        XCTAssertTrue(
            app.staticTexts[groupName].waitForExistence(timeout: 5),
            "The new group should appear on the root screen."
        )
    }

    func testMessageAddedInsideAGroupStaysThere() {
        let app = launchApp()
        let message = "Happy birthday!"

        addGroup(to: app)
        app.staticTexts[groupName].firstMatch.tap()

        XCTAssertTrue(
            app.navigationBars[groupName].waitForExistence(timeout: 5),
            "Tapping a group should open it."
        )

        addMessage(to: app, message: message)

        XCTAssertTrue(
            app.staticTexts[message].waitForExistence(timeout: 5),
            "The message should appear inside the group it was added from."
        )

        app.navigationBars[groupName].buttons.firstMatch.tap()
        XCTAssertTrue(
            app.navigationBars["Messages"].waitForExistence(timeout: 5),
            "Going back should return to the root screen."
        )
        XCTAssertFalse(
            app.staticTexts[message].exists,
            "A grouped message should not also be listed among the ungrouped ones."
        )
    }

    func testDeletingAGroupOnlyLeavesItsMessagesUngrouped() {
        let app = launchApp()
        let message = "Happy birthday!"

        addGroup(to: app)
        app.staticTexts[groupName].firstMatch.tap()
        XCTAssertTrue(app.navigationBars[groupName].waitForExistence(timeout: 5))

        addMessage(to: app, message: message)
        XCTAssertTrue(app.staticTexts[message].waitForExistence(timeout: 5))

        app.buttons["List Options"].firstMatch.tap()
        app.buttons["Delete List"].firstMatch.tap()

        let deleteGroupOnly = app.buttons["Delete List Only"]
        XCTAssertTrue(
            deleteGroupOnly.waitForExistence(timeout: 5),
            "Deleting a group with messages in it should ask what to do with them."
        )
        deleteGroupOnly.tap()

        XCTAssertTrue(
            app.navigationBars["Messages"].waitForExistence(timeout: 5),
            "Deleting the group should return to the root screen."
        )
        XCTAssertTrue(
            app.staticTexts[message].waitForExistence(timeout: 5),
            "The message should survive as an ungrouped one."
        )
        XCTAssertFalse(app.staticTexts[groupName].exists, "The group itself should be gone.")
    }

    func testAddMenuOffersBothKindsOfAdding() {
        let app = launchApp()

        addGroup(to: app)
        XCTAssertTrue(app.staticTexts[groupName].waitForExistence(timeout: 5))

        app.buttons["Add"].firstMatch.tap()

        XCTAssertTrue(
            app.buttons["Schedule Message"].waitForExistence(timeout: 5),
            "The plus menu should offer to add a message."
        )

        let addGroup = app.buttons["Add List"]
        XCTAssertTrue(
            addGroup.waitForExistence(timeout: 5),
            "The plus menu should offer to add a group."
        )
        addGroup.tap()

        XCTAssertTrue(
            app.navigationBars["New List"].waitForExistence(timeout: 5),
            "Choosing Add Group should open the group editor."
        )
    }

    func testMessageEditorCanCreateAndAssignAGroup() {
        let app = launchApp()

        app.buttons["Schedule Message"].firstMatch.tap()
        XCTAssertTrue(
            app.navigationBars["New Message"].waitForExistence(timeout: 5),
            "The message editor should open."
        )

        let newGroup = app.buttons["New List"]
        XCTAssertTrue(
            newGroup.waitForExistence(timeout: 5),
            "The editor should offer to make a group even before any exist."
        )
        newGroup.tap()

        nameAndSaveGroup(in: app)

        XCTAssertTrue(
            app.navigationBars["New Message"].waitForExistence(timeout: 5),
            "Saving the group should return to the message editor."
        )
        XCTAssertTrue(
            app.staticTexts[groupName].waitForExistence(timeout: 5),
            "The group just created should be selected in the editor."
        )
    }

    private func addGroup(to app: XCUIApplication) {
        app.buttons["Add List"].firstMatch.tap()
        nameAndSaveGroup(in: app)
    }

    private func nameAndSaveGroup(in app: XCUIApplication) {
        let editor = app.navigationBars["New List"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "The group editor should open.")

        let nameField = app.textFields["List name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "The name field should exist.")
        nameField.tap()
        nameField.typeText(groupName)

        XCTAssertTrue(editor.buttons["Save"].isEnabled, "Save should enable once the group is named.")
        editor.buttons["Save"].tap()
    }

    private func addMessage(to app: XCUIApplication, message: String) {
        app.buttons["Schedule Message"].firstMatch.tap()

        let editor = app.navigationBars["New Message"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "The message editor should open.")

        app.buttons["Choose a contact"].firstMatch.tap()
        XCTAssertTrue(
            app.pickerNavigationBar.waitForExistence(timeout: 10),
            "The contact picker should present."
        )
        app.staticTexts[contactName].firstMatch.tap()

        let messageField = app.textViews.firstMatch
        XCTAssertTrue(messageField.waitForExistence(timeout: 5))
        messageField.tap()
        messageField.typeText(message)

        XCTAssertTrue(editor.buttons["Save"].isEnabled, "Save should enable once both are set.")
        editor.buttons["Save"].tap()
    }
}
