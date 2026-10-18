import XCTest

extension XCUIApplication {

    private static let ownNavigationBars = ["Messages", "New Message", "Edit Message"]

    var pickerNavigationBar: XCUIElement {
        navigationBars
            .matching(NSPredicate(format: "NOT (identifier IN %@)", Self.ownNavigationBars))
            .firstMatch
    }
}
