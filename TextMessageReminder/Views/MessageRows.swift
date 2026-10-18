import SwiftData
import SwiftUI

struct MessageRows: View {

    let messages: [Message]

    /// The moment "next" is measured from, so every row agrees on it.
    let now: Date

    @Binding var editing: Message?

    @EnvironmentObject private var composer: MessageComposer
    @Environment(\.modelContext) private var modelContext

    /// Soonest first. A message with no upcoming date sinks to the bottom, and
    /// ties fall back to newest first so the order never shuffles between renders.
    private var ordered: [Message] {
        let nextDates: [UUID: Date] = Dictionary(uniqueKeysWithValues: messages.map { message in
            (message.identifier, message.nextFireDate(after: now) ?? .distantFuture)
        })

        return messages.sorted { lhs, rhs in
            let left = nextDates[lhs.identifier] ?? .distantFuture
            let right = nextDates[rhs.identifier] ?? .distantFuture
            if left != right { return left < right }
            return lhs.createdAt > rhs.createdAt
        }
    }

    var body: some View {
        let ordered = ordered

        ForEach(ordered) { message in
            MessageRow(
                message: message,
                now: now,
                onCompose: { composer.compose(message) }
            )
            .contentShape(Rectangle())
            .onTapGesture { editing = message }
            .swipeActions(edge: .leading) {
                Button {
                    toggle(message)
                } label: {
                    if message.isEnabled {
                        Label("Pause", systemImage: "pause.circle")
                    } else {
                        Label("Resume", systemImage: "play.circle")
                    }
                }
                .tint(message.isEnabled ? .orange : .green)
            }
        }
        .onDelete { delete(ordered, at: $0) }
    }

    private func toggle(_ message: Message) {
        message.isEnabled.toggle()
        try? modelContext.save()

        let identifier = message.notificationIdentifier
        let schedule = message.schedule
        Task { await NotificationScheduler.reschedule(identifier: identifier, schedule: schedule) }
    }

    private func delete(_ shown: [Message], at offsets: IndexSet) {
        for index in offsets {
            let message = shown[index]
            NotificationScheduler.cancel(identifier: message.notificationIdentifier)
            modelContext.delete(message)
        }
        try? modelContext.save()
    }
}
