import Contacts
import Foundation

enum StartupPermissions {

    private static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-uitesting")
    }

    static func requestAll() async {
        await NotificationScheduler.requestAuthorization()
        await requestContacts()
    }

    @discardableResult
    static func requestContacts() async -> Bool {
        if isUITesting { return false }

        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited:
            return true
        case .notDetermined:
            return (try? await CNContactStore().requestAccess(for: .contacts)) ?? false
        default:
            return false
        }
    }
}
