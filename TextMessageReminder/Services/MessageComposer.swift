import Foundation
import UIKit

struct ComposeNotice: Equatable {
    let title: String
    let message: String
}

@MainActor
final class MessageComposer: ObservableObject {

    @Published var notice: ComposeNotice?

    /// Opens Messages with the draft. A contact with no phone number or email
    /// can't be addressed there — they're reached in some other app — so the
    /// text goes to the clipboard instead, ready to paste wherever that is.
    func compose(_ message: Message) {
        if MessagesLink.open(for: message) { return }

        UIPasteboard.general.string = message.text
        notice = ComposeNotice(
            title: "Message copied",
            message: "\(message.contactName.isEmpty ? "This contact" : message.contactName) has no phone number or email, so paste it into whichever app you chat in."
        )
    }
}
