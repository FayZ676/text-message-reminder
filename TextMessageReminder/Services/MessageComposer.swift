import Foundation
import UIKit

enum MessageComposer {

    private static let handleAllowed = CharacterSet(charactersIn: "+0123456789@._-")

    static func normalizedHandle(_ handle: String) -> String {
        String(handle.unicodeScalars.filter { handleAllowed.contains($0) })
    }

    static func composeURL(handle: String, body: String) -> URL? {
        let cleanedHandle = normalizedHandle(handle)
        guard !cleanedHandle.isEmpty else { return nil }

        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""

        return URL(string: "sms:\(cleanedHandle)&body=\(encodedBody)")
    }

    static func composeURL(for reminder: Reminder) -> URL? {
        composeURL(handle: reminder.contactHandle, body: reminder.message)
    }

    @MainActor
    @discardableResult
    static func open(for reminder: Reminder) -> Bool {
        open(for: reminder, body: reminder.message)
    }

    @MainActor
    @discardableResult
    static func open(for reminder: Reminder, body: String) -> Bool {
        guard let url = composeURL(handle: reminder.contactHandle, body: body) else { return false }
        UIApplication.shared.open(url)
        return true
    }
}
