import SwiftData
import SwiftUI

struct MessageListView: View {

    @EnvironmentObject private var coordinator: NotificationCoordinator
    @Environment(\.modelContext) private var modelContext

    @StateObject private var composer = MessageComposer()

    @Query(sort: \Message.createdAt, order: .reverse) private var messages: [Message]
    @Query(sort: \MessageGroup.createdAt) private var groups: [MessageGroup]

    @State private var isAddingMessage = false
    @State private var isAddingGroup = false
    @State private var editingMessage: Message?
    @State private var isShowingSettings = false
    @State private var groupPendingDeletion: MessageGroup?

    private var ungrouped: [Message] {
        messages.filter { $0.group == nil }
    }

    var body: some View {
        NavigationStack {
            Group {
                if messages.isEmpty && groups.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: MessageGroup.self) { group in
                GroupDetailView(group: group)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            isAddingMessage = true
                        } label: {
                            Label("Add Message", systemImage: "plus.message")
                        }

                        Button {
                            isAddingGroup = true
                        } label: {
                            Label("Add Group", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingMessage) {
                MessageEditorView()
            }
            .sheet(isPresented: $isAddingGroup) {
                GroupEditorView()
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .sheet(item: $editingMessage) { message in
                MessageEditorView(existing: message)
            }
            .groupDeletionConfirmation($groupPendingDeletion)
            .alert("Couldn't open Messages", isPresented: Binding(
                get: { composer.failure != nil },
                set: { if !$0 { composer.failure = nil } }
            )) {
                Button("OK") { composer.failure = nil }
            } message: {
                Text(composer.failure ?? "")
            }
        }
        .environmentObject(composer)
        .task {
            // A cold launch from a notification resolves the tap before this
            // view exists, and `onChange` only reports transitions it was around
            // for — so a tap already waiting has to be claimed here.
            composePendingMessage()

            await StartupPermissions.requestAll()
            let schedules = messages.compactMap(\.schedule)
            await NotificationScheduler.syncAll(schedules)
        }
        .onChange(of: coordinator.pendingMessageID) { _, _ in
            composePendingMessage()
        }
        // The tap can name a message the store hasn't handed us yet; the query
        // filling in is the cue to try matching it again.
        .onChange(of: messages.count) { _, _ in
            composePendingMessage()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Messages", systemImage: "message.badge.clock")
        } description: {
            Text("Add a message, a contact, and how often you want to send it. We'll nudge you and open Messages with it ready to go.")
        } actions: {
            Button("Add Message") { isAddingMessage = true }
                .buttonStyle(.borderedProminent)
            Button("Add Group") { isAddingGroup = true }
        }
    }

    private var list: some View {
        List {
            if !groups.isEmpty {
                Section("Groups") {
                    ForEach(groups) { group in
                        NavigationLink(value: group) {
                            GroupRow(group: group)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                requestDeletion(of: group)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            if !ungrouped.isEmpty {
                Section("Messages") {
                    MessageRows(messages: ungrouped, editing: $editingMessage)
                }
            }
        }
    }

    /// Turns a tapped notification into an open Messages thread. The tap is only
    /// cleared once it has been matched to a message, so one that arrives ahead
    /// of the store loading is still honoured on the next pass.
    private func composePendingMessage() {
        guard
            let id = coordinator.pendingMessageID,
            let message = messages.first(where: { $0.identifier == id })
        else { return }

        coordinator.pendingMessageID = nil
        composer.compose(message)
    }

    private func requestDeletion(of group: MessageGroup) {
        guard group.messages.isEmpty else {
            groupPendingDeletion = group
            return
        }

        group.delete(includingMessages: false, in: modelContext)
        try? modelContext.save()
    }
}

private struct GroupRow: View {
    let group: MessageGroup

    var body: some View {
        HStack(spacing: Layout.regular) {
            GroupGlyph(group: group, diameter: Layout.listRowIconDiameter)

            Text(group.name)
                .font(.headline)

            Spacer()

            Text("\(group.messages.count)")
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(group.messages.count) messages")
        }
    }
}
