import Contacts
import Foundation

enum ContactBirthdayError: LocalizedError {
    case permissionDenied
    case contactUnavailable
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "This app needs access to Contacts to save a birthday. You can grant it in Settings."
        case .contactUnavailable:
            "That contact couldn't be found in your address book."
        case .saveFailed(let detail):
            "The birthday couldn't be saved to the contact card.\n\n\(detail)"
        }
    }
}

enum ContactBirthdayStore {

    private static var keys: [CNKeyDescriptor] {
        [CNContactBirthdayKey as CNKeyDescriptor]
    }

    static func birthday(forContactIdentifier identifier: String) async -> DateComponents? {
        guard !identifier.isEmpty, await StartupPermissions.requestContacts() else { return nil }

        return await Task.detached(priority: .userInitiated) {
            let contact = try? CNContactStore().unifiedContact(
                withIdentifier: identifier,
                keysToFetch: keys
            )
            return contact?.birthday
        }.value
    }

    static func setBirthday(
        _ birthday: DateComponents,
        forContactIdentifier identifier: String
    ) async throws {
        guard !identifier.isEmpty else { throw ContactBirthdayError.contactUnavailable }
        guard await StartupPermissions.requestContacts() else { throw ContactBirthdayError.permissionDenied }

        try await Task.detached(priority: .userInitiated) {
            let store = CNContactStore()

            guard
                let contact = try? store.unifiedContact(withIdentifier: identifier, keysToFetch: keys),
                let mutable = contact.mutableCopy() as? CNMutableContact
            else {
                throw ContactBirthdayError.contactUnavailable
            }

            mutable.birthday = birthday

            let request = CNSaveRequest()
            request.update(mutable)

            do {
                try store.execute(request)
            } catch {
                throw ContactBirthdayError.saveFailed(error.localizedDescription)
            }
        }.value
    }
}

extension DateComponents {

    var recurringMonthAndDay: (month: Int, day: Int)? {
        guard let month, let day else { return nil }
        return (month, min(day, Frequency.lastSelectableDay(inMonth: month)))
    }
}
