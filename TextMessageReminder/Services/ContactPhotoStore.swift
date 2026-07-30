import Contacts
import Foundation

enum ContactPhotoStore {

    static func thumbnail(forContactIdentifier identifier: String) async -> Data? {
        guard !identifier.isEmpty, await StartupPermissions.requestContacts() else { return nil }

        return await Task.detached(priority: .userInitiated) {
            let keys = [CNContactThumbnailImageDataKey as CNKeyDescriptor]
            let contact = try? CNContactStore().unifiedContact(
                withIdentifier: identifier,
                keysToFetch: keys
            )
            return contact?.thumbnailImageData
        }.value
    }
}
