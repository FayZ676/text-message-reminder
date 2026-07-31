import Foundation
import SwiftData

@Model
final class MessageGroup {
    var identifier: UUID

    var name: String

    var colorRaw: String

    var symbolName: String

    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Message.group)
    var messages: [Message] = []

    init(
        identifier: UUID = UUID(),
        name: String = "",
        color: GroupColor = .fallback,
        symbolName: String = GroupSymbol.fallback,
        createdAt: Date = Date()
    ) {
        self.identifier = identifier
        self.name = name
        self.colorRaw = color.rawValue
        self.symbolName = symbolName
        self.createdAt = createdAt
    }

    var color: GroupColor {
        get { GroupColor(rawValue: colorRaw) ?? .fallback }
        set { colorRaw = newValue.rawValue }
    }

    var sortedMessages: [Message] {
        messages.sorted { $0.createdAt > $1.createdAt }
    }

    var deletionNote: String {
        messages.count == 1
            ? "This group has 1 message."
            : "This group has \(messages.count) messages."
    }

    func delete(includingMessages: Bool, in context: ModelContext) {
        if includingMessages {
            for message in sortedMessages {
                NotificationScheduler.cancel(identifier: message.notificationIdentifier)
                context.delete(message)
            }
        }

        context.delete(self)
    }
}
