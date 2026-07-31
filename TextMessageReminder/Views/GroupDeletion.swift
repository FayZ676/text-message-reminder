import SwiftData
import SwiftUI

extension View {
    func groupDeletionConfirmation(
        _ group: Binding<MessageGroup?>,
        onDelete: @escaping () -> Void = {}
    ) -> some View {
        modifier(GroupDeletionConfirmation(group: group, onDelete: onDelete))
    }
}

private struct GroupDeletionConfirmation: ViewModifier {

    @Binding var group: MessageGroup?

    let onDelete: () -> Void

    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content.confirmationDialog(
            group.map { "Delete \"\($0.name)\"?" } ?? "",
            isPresented: Binding(
                get: { group != nil },
                set: { if !$0 { group = nil } }
            ),
            titleVisibility: .visible,
            presenting: group
        ) { target in
            Button("Delete Group and Messages", role: .destructive) {
                delete(target, includingMessages: true)
            }
            Button("Delete Group Only") {
                delete(target, includingMessages: false)
            }
            Button("Cancel", role: .cancel) { group = nil }
        } message: { target in
            Text(target.deletionNote)
        }
    }

    private func delete(_ target: MessageGroup, includingMessages: Bool) {
        target.delete(includingMessages: includingMessages, in: modelContext)
        try? modelContext.save()
        group = nil
        onDelete()
    }
}
