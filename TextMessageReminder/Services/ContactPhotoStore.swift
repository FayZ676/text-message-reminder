import Contacts
import Foundation

/// Reads a contact's photo out of the user's address book.
///
/// The `CNContact` the picker hands back is only partially fetched, so reading
/// `thumbnailImageData` off it would raise `CNPropertyNotFetchedException`. A
/// photo has to come from `CNContactStore` instead, which means holding
/// Contacts permission — the picker alone needs none.
///
/// Every failure here is deliberately silent. The avatar falls back to a
/// monogram, and nothing about creating or sending a message depends on the
/// photo, so a denied prompt or a since-deleted contact isn't worth an alert.
enum ContactPhotoStore {

    /// The contact's thumbnail, or `nil` if there isn't one we're allowed to read.
    static func thumbnail(forContactIdentifier identifier: String) async -> Data? {
        // `requestContacts` owns the authorization switch, and opts UI tests out:
        // the permission alert belongs to a system process and would take
        // keyboard focus off the form mid-flow.
        guard !identifier.isEmpty, await StartupPermissions.requestContacts() else { return nil }

        // `unifiedContact` is synchronous disk I/O; keep it off the main actor.
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
