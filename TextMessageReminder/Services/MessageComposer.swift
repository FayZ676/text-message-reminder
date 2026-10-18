import Foundation
import UIKit

@MainActor
final class MessageComposer: ObservableObject {

    /// A short confirmation shown over whichever screen is up, then cleared.
    @Published private(set) var toast: String?

    private var toastDismissal: Task<Void, Never>?

    /// Opens Messages with the draft. A contact with no phone number or email
    /// can't be addressed there — they're reached in some other app — so the
    /// text goes to the clipboard instead, ready to paste wherever that is.
    func compose(_ message: Message) {
        if MessagesLink.open(for: message) { return }

        UIPasteboard.general.string = message.text
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        show("Message copied — paste it wherever you chat")
    }

    private func show(_ text: String) {
        toast = text

        toastDismissal?.cancel()
        toastDismissal = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            toast = nil
        }
    }
}
