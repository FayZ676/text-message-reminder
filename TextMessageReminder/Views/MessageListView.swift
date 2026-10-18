import SwiftData
import SwiftUI

struct MessageListView: View {

    @EnvironmentObject private var coordinator: NotificationCoordinator
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var composer = MessageComposer()

    @Query(sort: \Message.createdAt, order: .reverse) private var messages: [Message]
    @Query(sort: \MessageGroup.createdAt) private var groups: [MessageGroup]

    @State private var isAddingMessage = false
    @State private var isAddingGroup = false
    @State private var editingMessage: Message?
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
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            isAddingMessage = true
                        } label: {
                            Label("Schedule Message", systemImage: "plus.message")
                        }

                        Button {
                            isAddingGroup = true
                        } label: {
                            Label("Add List", systemImage: "text.badge.plus")
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
            .sheet(item: $editingMessage) { message in
                MessageEditorView(existing: message)
            }
            .groupDeletionConfirmation($groupPendingDeletion)
        }
        // On the stack itself, not its root, so it also covers a pushed list.
        .overlay(alignment: .bottom) {
            if let toast = composer.toast {
                Toast(text: toast)
                    .padding(.bottom, Layout.gutter)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: composer.toast)
        .environmentObject(composer)
        .task {
            // A cold launch from a notification resolves the tap before this
            // view exists, and `onChange` only reports transitions it was around
            // for — so a tap already waiting has to be claimed here.
            composePendingMessage()

            await StartupPermissions.requestAll()
            await refreshBirthdays()
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
        // A tap on the lock screen arrives while the app is still inactive,
        // behind Face ID, and iOS drops a URL opened from there. Becoming active
        // is when Messages can actually be opened.
        .onChange(of: scenePhase) { _, _ in
            composePendingMessage()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Messages", systemImage: "message.badge.clock")
        } description: {
            Text("Add a message, a contact, and how often you want to send it. We'll nudge you and open Messages with it ready to go.")
        } actions: {
            Button("Schedule Message") { isAddingMessage = true }
                .buttonStyle(.borderedProminent)
            Button("Add List") { isAddingGroup = true }
        }
    }

    private var list: some View {
        TimelineView(.everyMinute) { context in
            List {
                groupsSection

                if !ungrouped.isEmpty {
                    Section("Messages") {
                        MessageRows(messages: ungrouped, now: context.date, editing: $editingMessage)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var groupsSection: some View {
        if !groups.isEmpty {
            Section("Lists") {
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
    }

    /// Turns a tapped notification into an open Messages thread. The tap is only
    /// cleared once it has been matched to a message and the app is active, so
    /// one that arrives ahead of the store loading or the phone unlocking is
    /// still honoured on the next pass.
    private func composePendingMessage() {
        guard
            scenePhase == .active,
            let id = coordinator.pendingMessageID,
            let message = messages.first(where: { $0.identifier == id })
        else { return }

        coordinator.pendingMessageID = nil
        composer.compose(message)
    }

    private func refreshBirthdays() async {
        var didChange = false

        for message in messages where message.frequency == .birthday {
            guard !message.contactIdentifier.isEmpty else { continue }

            guard
                let birthday = await ContactBirthdayStore
                    .birthday(forContactIdentifier: message.contactIdentifier),
                let date = birthday.recurringMonthAndDay,
                message.month != date.month || message.dayOfMonth != date.day
            else { continue }

            message.month = date.month
            message.dayOfMonth = date.day
            didChange = true
        }

        if didChange {
            try? modelContext.save()
        }
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

private struct Toast: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, Layout.gutter)
            .padding(.vertical, Layout.regular)
            .background(.regularMaterial, in: .capsule)
            .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
            .padding(.horizontal, Layout.gutter)
            .accessibilityAddTraits(.isStaticText)
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
