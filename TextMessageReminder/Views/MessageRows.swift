import SwiftData
import SwiftUI

struct MessageRows: View {

    let messages: [Message]

    @Binding var editing: Message?

    @EnvironmentObject private var composer: MessageComposer
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ForEach(messages) { message in
            MessageRow(
                message: message,
                isGenerating: composer.generatingID == message.identifier,
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
        .onDelete(perform: delete)
    }

    private func toggle(_ message: Message) {
        message.isEnabled.toggle()
        try? modelContext.save()

        let identifier = message.notificationIdentifier
        let schedule = message.schedule
        Task { await NotificationScheduler.reschedule(identifier: identifier, schedule: schedule) }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let message = messages[index]
            NotificationScheduler.cancel(identifier: message.notificationIdentifier)
            modelContext.delete(message)
        }
        try? modelContext.save()
    }
}
