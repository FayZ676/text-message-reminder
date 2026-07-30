import SwiftData
import SwiftUI

struct ReminderListView: View {

    @EnvironmentObject private var coordinator: NotificationCoordinator
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Reminder.createdAt, order: .reverse) private var reminders: [Reminder]

    @State private var isAddingReminder = false
    @State private var editingReminder: Reminder?
    @State private var isShowingSettings = false
    @State private var composeFailure: String?

    @State private var generatingReminderID: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if reminders.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingReminder = true
                    } label: {
                        Label("Add Reminder", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingReminder) {
                ReminderEditorView()
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .sheet(item: $editingReminder) { reminder in
                ReminderEditorView(existing: reminder)
            }
            .alert("Couldn't open Messages", isPresented: Binding(
                get: { composeFailure != nil },
                set: { if !$0 { composeFailure = nil } }
            )) {
                Button("OK") { composeFailure = nil }
            } message: {
                Text(composeFailure ?? "")
            }
        }
        .task {
            // A cold launch from a notification resolves the tap before this
            // view exists, and `onChange` only reports transitions it was around
            // for — so a tap already waiting has to be claimed here.
            composePendingReminder()

            await StartupPermissions.requestAll()
            let schedules = reminders.compactMap(\.schedule)
            await NotificationScheduler.syncAll(schedules)
        }
        .onChange(of: coordinator.pendingReminderID) { _, _ in
            composePendingReminder()
        }
        // The tap can name a reminder the store hasn't handed us yet; the query
        // filling in is the cue to try matching it again.
        .onChange(of: reminders.count) { _, _ in
            composePendingReminder()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Reminders", systemImage: "message.badge.clock")
        } description: {
            Text("Add a message, a contact, and how often you want to send it. We'll nudge you and open Messages with it ready to go.")
        } actions: {
            Button("Add Reminder") { isAddingReminder = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var list: some View {
        List {
            ForEach(reminders) { reminder in
                ReminderRow(
                    reminder: reminder,
                    isGenerating: generatingReminderID == reminder.identifier,
                    onCompose: { compose(reminder) }
                )
                .contentShape(Rectangle())
                .onTapGesture { editingReminder = reminder }
                .swipeActions(edge: .leading) {
                    Button {
                        toggle(reminder)
                    } label: {
                        if reminder.isEnabled {
                            Label("Pause", systemImage: "pause.circle")
                        } else {
                            Label("Resume", systemImage: "play.circle")
                        }
                    }
                    .tint(reminder.isEnabled ? .orange : .green)
                }
            }
            .onDelete(perform: delete)
        }
    }

    /// Turns a tapped notification into an open Messages thread. The tap is only
    /// cleared once it has been matched to a reminder, so one that arrives ahead
    /// of the store loading is still honoured on the next pass.
    private func composePendingReminder() {
        guard
            let id = coordinator.pendingReminderID,
            let reminder = reminders.first(where: { $0.identifier == id })
        else { return }

        coordinator.pendingReminderID = nil
        compose(reminder)
    }

    private func compose(_ reminder: Reminder) {
        guard reminder.usesVariations else {
            openMessages(for: reminder, body: reminder.message)
            return
        }

        guard generatingReminderID == nil else { return }

        let request = VariationRequest(
            baseMessage: reminder.message,
            contactName: reminder.contactName,
            title: reminder.effectiveTitle
        )

        generatingReminderID = reminder.identifier

        Task {
            var body = reminder.message
            var failure: String?

            do {
                body = try await MessageVariationService.variation(for: request)
            } catch MessageVariationError.missingAPIKey {
                failure = "Add your Anthropic API key in Settings to vary this message. Sending it as written for now."
            } catch MessageVariationError.requestFailed(let reason) {
                failure = "Couldn't rewrite this message, so it's going out as written.\n\n\(reason)"
            } catch {
                failure = "Couldn't rewrite this message, so it's going out as written."
            }

            generatingReminderID = nil
            openMessages(for: reminder, body: body)

            if composeFailure == nil { composeFailure = failure }
        }
    }

    private func openMessages(for reminder: Reminder, body: String) {
        if !MessageComposer.open(for: reminder, body: body) {
            composeFailure = "\"\(reminder.effectiveTitle)\" doesn't have a usable phone number or email yet."
        }
    }

    private func toggle(_ reminder: Reminder) {
        reminder.isEnabled.toggle()
        try? modelContext.save()

        let identifier = reminder.notificationIdentifier
        let schedule = reminder.schedule
        Task { await NotificationScheduler.reschedule(identifier: identifier, schedule: schedule) }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let reminder = reminders[index]
            NotificationScheduler.cancel(identifier: reminder.notificationIdentifier)
            modelContext.delete(reminder)
        }
        try? modelContext.save()
    }
}

private struct ReminderRow: View {
    let reminder: Reminder
    let isGenerating: Bool
    let onCompose: () -> Void

    /// Contact and cadence share one line rather than costing the row a line each.
    /// An untitled reminder's title is already "Text <contact>", so naming the
    /// contact again there would just be the same word twice.
    private var summary: String {
        var parts: [String] = []

        if !reminder.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(reminder.contactName.isEmpty ? reminder.contactHandle : reminder.contactName)
        }

        parts.append(reminder.frequencySummary)

        // The row used to carry a switch; with it gone, the dimming alone is too
        // quiet to explain why a reminder never fires.
        if !reminder.isEnabled { parts.append("Paused") }

        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: Layout.regular) {
            ContactAvatar(
                name: reminder.contactName,
                handle: reminder.contactHandle,
                imageData: reminder.contactImageData
            )

            content
        }
        .opacity(reminder.isEnabled ? 1 : 0.5)
        // Left alone the separator starts at the row's deepest last subview. Zero
        // runs it the full width, so it meets the row's leading inset the same way
        // it already meets the trailing one.
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        .listRowInsets(EdgeInsets(
            top: Layout.regular,
            leading: Layout.gutter,
            bottom: Layout.regular,
            trailing: Layout.gutter
        ))
    }

    private var content: some View {
        // The button rides alongside the whole text column rather than under it,
        // so it lands beside the title instead of on a line of its own.
        HStack(alignment: .top, spacing: Layout.regular) {
            VStack(alignment: .leading, spacing: Layout.snug) {
                VStack(alignment: .leading, spacing: Layout.tight) {
                    Text(reminder.effectiveTitle)
                        .font(.headline)

                    // One line: the row is a glance at what's queued, and the full
                    // text is a tap away in the editor.
                    Text(reminder.message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            composeButton
        }
    }

    private var composeButton: some View {
        Button(action: onCompose) {
            Group {
                if isGenerating {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: "arrow.up.message")
                        .font(.subheadline)
                }
            }
            // The glyph is wider than it is tall, so left to itself the circle
            // comes out an oval that crowds the arrow. Squaring the label gives a
            // real circle and even space on every side.
            .frame(width: Layout.iconButtonGlyph, height: Layout.iconButtonGlyph)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .controlSize(.small)
        .disabled(isGenerating)
        .accessibilityLabel(isGenerating ? "Writing message" : "Compose")
    }
}
