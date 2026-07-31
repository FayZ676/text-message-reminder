import SwiftData
import SwiftUI

struct GroupDetailView: View {

    let group: MessageGroup

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isAddingMessage = false
    @State private var isEditingGroup = false
    @State private var editingMessage: Message?
    @State private var groupPendingDeletion: MessageGroup?

    var body: some View {
        Group {
            if group.messages.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingMessage = true
                } label: {
                    Label("Add Message", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        isEditingGroup = true
                    } label: {
                        Label("Edit Group", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        requestDeletion()
                    } label: {
                        Label("Delete Group", systemImage: "trash")
                    }
                } label: {
                    Label("Group Options", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isAddingMessage) {
            MessageEditorView(group: group)
        }
        .sheet(isPresented: $isEditingGroup) {
            GroupEditorView(existing: group)
        }
        .sheet(item: $editingMessage) { message in
            MessageEditorView(existing: message)
        }
        .groupDeletionConfirmation($groupPendingDeletion) { dismiss() }
    }

    private var list: some View {
        List {
            MessageRows(messages: group.sortedMessages, editing: $editingMessage)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(group.name, systemImage: group.symbolName)
        } description: {
            Text("Nothing in this group yet. Messages you add here stay together and behave exactly like any other.")
        } actions: {
            Button("Add Message") { isAddingMessage = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private func requestDeletion() {
        guard group.messages.isEmpty else {
            groupPendingDeletion = group
            return
        }

        group.delete(includingMessages: false, in: modelContext)
        try? modelContext.save()
        dismiss()
    }
}
