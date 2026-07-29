import XCTest

extension XCUIApplication {

    private static let ownNavigationBars = ["Reminders", "New Reminder", "Edit Reminder", "Settings"]

    var pickerNavigationBar: XCUIElement {
        navigationBars
            .matching(NSPredicate(format: "NOT (identifier IN %@)", Self.ownNavigationBars))
            .firstMatch
    }
}
