import Foundation

@MainActor
final class MessageComposer: ObservableObject {

    @Published var generatingID: UUID?

    @Published var failure: String?

    func compose(_ message: Message) {
        guard message.usesVariations else {
            openMessages(for: message, body: message.text)
            return
        }

        guard generatingID == nil else { return }

        let request = VariationRequest(
            baseMessage: message.text,
            contactName: message.contactName,
            title: message.effectiveTitle
        )

        generatingID = message.identifier

        Task {
            var body = message.text
            var reason: String?

            do {
                body = try await MessageVariationService.variation(for: request)
            } catch MessageVariationError.missingAPIKey {
                reason = "Add your Anthropic API key in Settings to vary this message. Sending it as written for now."
            } catch MessageVariationError.requestFailed(let detail) {
                reason = "Couldn't rewrite this message, so it's going out as written.\n\n\(detail)"
            } catch {
                reason = "Couldn't rewrite this message, so it's going out as written."
            }

            generatingID = nil
            openMessages(for: message, body: body)

            if failure == nil { failure = reason }
        }
    }

    private func openMessages(for message: Message, body: String) {
        if !MessagesLink.open(for: message, body: body) {
            failure = "\"\(message.effectiveTitle)\" doesn't have a usable phone number or email yet."
        }
    }
}
