import XCTest

extension XCUIApplication {

    private static let ownNavigationBars = ["Messages", "New Message", "Edit Message", "Settings"]

    var pickerNavigationBar: XCUIElement {
        navigationBars
            .matching(NSPredicate(format: "NOT (identifier IN %@)", Self.ownNavigationBars))
            .firstMatch
    }
}
