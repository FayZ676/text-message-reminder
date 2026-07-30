import SwiftData
import SwiftUI

struct ReminderEditorView: View {

    let existing: Reminder?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var message: String
    @State private var usesVariations: Bool
    @State private var contactName: String
    @State private var contactHandle: String
    @State private var contactImageData: Data?
    @State private var frequency: Frequency
    @State private var time: Date
    @State private var weekday: Int
    @State private var monthlyDay: Int
    @State private var yearlyDay: Int
    @State private var yearlyMonth: Int

    @State private var isShowingContactPicker = false

    @State private var saveFailure: String?

    init(existing: Reminder? = nil) {
        self.existing = existing

        let reminder = existing
        _title = State(initialValue: reminder?.title ?? "")
        _message = State(initialValue: reminder?.message ?? "")
        _usesVariations = State(initialValue: reminder?.usesVariations ?? false)
        _contactName = State(initialValue: reminder?.contactName ?? "")
        _contactHandle = State(initialValue: reminder?.contactHandle ?? "")
        _contactImageData = State(initialValue: reminder?.contactImageData)
        _frequency = State(initialValue: reminder?.frequency ?? .weekly)
        _weekday = State(initialValue: reminder?.weekday ?? 2)
        let today = Self.todaysMonthAndDay()
        let isYearly = reminder?.frequency == .yearly
        _monthlyDay = State(initialValue: isYearly ? 1 : (reminder?.dayOfMonth ?? 1))
        _yearlyDay = State(initialValue: isYearly ? (reminder?.dayOfMonth ?? today.day) : today.day)
        _yearlyMonth = State(initialValue: isYearly ? (reminder?.month ?? today.month) : today.month)

        var components = DateComponents()
        components.hour = reminder?.hour ?? 9
        components.minute = reminder?.minute ?? 0
        _time = State(initialValue: Calendar.current.date(from: components) ?? Date())
    }

    private var canSave: Bool {
        !contactHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var missingRequirement: String? {
        let hasContact = !contactHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasMessage = !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        switch (hasContact, hasMessage) {
        case (true, true): return nil
        case (false, true): return "Choose a contact to save this reminder."
        case (true, false): return "Write the message you want to send to save this reminder."
        case (false, false): return "Choose a contact and write a message to save this reminder."
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Who") {
                    Button {
                        isShowingContactPicker = true
                    } label: {
                        HStack(spacing: Layout.regular) {
                            ContactAvatar(
                                name: contactName,
                                handle: contactHandle,
                                imageData: contactImageData
                            )

                            if contactHandle.isEmpty {
                                Text("Choose a contact")
                            } else {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contactName.isEmpty ? contactHandle : contactName)
                                        .foregroundStyle(.primary)
                                    if !contactName.isEmpty {
                                        Text(contactHandle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Section {
                    TextEditor(text: $message)
                        .frame(minHeight: Layout.messageEditorMinHeight)
                        .overlay(alignment: .topLeading) {
                            if message.isEmpty {
                                Text("What should the message say?")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, Layout.textEditorTopInset)
                                    .padding(.leading, Layout.textEditorTextInset)
                                    .allowsHitTesting(false)
                            }
                        }
                        .listRowInsets(EdgeInsets(
                            top: Layout.snug,
                            leading: Layout.gutter - Layout.textEditorTextInset,
                            bottom: Layout.snug,
                            trailing: Layout.gutter - Layout.textEditorTextInset
                        ))

                    Toggle("Vary this message", isOn: $usesVariations)
                } header: {
                    Text("Message")
                } footer: {
                    if usesVariations {
                        Text("Claude rewrites this into fresh wording each time you compose, so a recurring message doesn't read the same every week. Needs an API key in Settings. The notification itself still shows the text as written.")
                    }
                }

                Section("Reminder title") {
                    TextField("Optional, e.g. Check in on Mom", text: $title)
                }

                scheduleSection

                if let missingRequirement {
                    Section {
                        EmptyView()
                    } footer: {
                        Label(missingRequirement, systemImage: "exclamationmark.circle")
                    }
                }
            }
            .onChange(of: yearlyMonth) { clampYearlyDay() }
            .navigationTitle(existing == nil ? "New Reminder" : "Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $isShowingContactPicker) {
                ContactPickerView { selection in
                    guard let selection else { return }

                    contactName = selection.name
                    contactHandle = selection.handle

                    // Clear the old photo first so an unphotographed contact
                    // doesn't briefly wear the previous one's face.
                    contactImageData = nil
                    let identifier = selection.identifier
                    Task {
                        contactImageData = await ContactPhotoStore
                            .thumbnail(forContactIdentifier: identifier)
                    }
                }
                .ignoresSafeArea()
            }
            .alert("Couldn't save this reminder", isPresented: Binding(
                get: { saveFailure != nil },
                set: { if !$0 { saveFailure = nil } }
            )) {
                Button("OK") { saveFailure = nil }
            } message: {
                Text(saveFailure ?? "")
            }
        }
    }

    @ViewBuilder
    private var scheduleSection: some View {
        Section {
            Picker("Repeats", selection: $frequency) {
                ForEach(Frequency.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }

            DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)

            switch frequency {
            case .daily:
                EmptyView()
            case .weekly:
                Picker("Day", selection: $weekday) {
                    ForEach(1...7, id: \.self) { day in
                        Text(Frequency.weekdayName(day)).tag(day)
                    }
                }
            case .monthly:
                Picker("Day of month", selection: $monthlyDay) {
                    ForEach(1...28, id: \.self) { day in
                        Text(Frequency.ordinal(day)).tag(day)
                    }
                }
            case .yearly:
                Picker("Month", selection: $yearlyMonth) {
                    ForEach(1...12, id: \.self) { value in
                        Text(Frequency.monthName(value)).tag(value)
                    }
                }
                Picker("Day", selection: $yearlyDay) {
                    ForEach(1...Frequency.lastSelectableDay(inMonth: yearlyMonth), id: \.self) { day in
                        Text(Frequency.ordinal(day)).tag(day)
                    }
                }
            }
        } header: {
            Text("When")
        } footer: {
            if let dayCapNote {
                Text(dayCapNote)
            }
        }
    }

    private var dayCapNote: String? {
        switch frequency {
        case .daily, .weekly:
            nil
        case .monthly:
            "Capped at the 28th so the reminder fires in every month."
        case .yearly:
            yearlyMonth == 2 ? "Capped at the 28th so the reminder fires in every year." : nil
        }
    }

    private static func todaysMonthAndDay() -> (month: Int, day: Int) {
        let components = Calendar.current.dateComponents([.month, .day], from: Date())
        let month = components.month ?? 1
        let day = min(components.day ?? 1, Frequency.lastSelectableDay(inMonth: month))
        return (month, day)
    }

    private func clampYearlyDay() {
        let lastDay = Frequency.lastSelectableDay(inMonth: yearlyMonth)
        if yearlyDay > lastDay {
            yearlyDay = lastDay
        }
    }

    private func save() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let reminder = existing ?? Reminder()

        reminder.title = title
        reminder.message = message
        reminder.usesVariations = usesVariations
        reminder.contactName = contactName
        reminder.contactHandle = contactHandle
        reminder.contactImageData = contactImageData
        reminder.frequency = frequency
        reminder.hour = components.hour ?? 9
        reminder.minute = components.minute ?? 0
        reminder.weekday = weekday
        reminder.dayOfMonth = frequency == .yearly ? yearlyDay : monthlyDay
        reminder.month = yearlyMonth

        if existing == nil {
            modelContext.insert(reminder)
        }

        do {
            try modelContext.save()
        } catch {
            saveFailure = error.localizedDescription
            return
        }

        let identifier = reminder.notificationIdentifier
        let schedule = reminder.schedule
        Task { await NotificationScheduler.reschedule(identifier: identifier, schedule: schedule) }

        dismiss()
    }
}
