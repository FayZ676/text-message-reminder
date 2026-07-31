import Foundation
import UIKit

enum MessagesLink {

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

    static func composeURL(for message: Message) -> URL? {
        composeURL(handle: message.contactHandle, body: message.text)
    }

    @MainActor
    @discardableResult
    static func open(for message: Message) -> Bool {
        open(for: message, body: message.text)
    }

    @MainActor
    @discardableResult
    static func open(for message: Message, body: String) -> Bool {
        guard let url = composeURL(handle: message.contactHandle, body: body) else { return false }
        UIApplication.shared.open(url)
        return true
    }
}
