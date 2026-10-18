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
                    Label("Schedule Message", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        isEditingGroup = true
                    } label: {
                        Label("Edit List", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        requestDeletion()
                    } label: {
                        Label("Delete List", systemImage: "trash")
                    }
                } label: {
                    Label("List Options", systemImage: "ellipsis.circle")
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
        TimelineView(.everyMinute) { context in
            List {
                MessageRows(messages: group.messages, now: context.date, editing: $editingMessage)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(group.name, systemImage: group.symbolName)
        } description: {
            Text("Nothing in this list yet. Messages you add here stay together and behave exactly like any other.")
        } actions: {
            Button("Schedule Message") { isAddingMessage = true }
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
