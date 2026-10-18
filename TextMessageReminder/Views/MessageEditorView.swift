import SwiftData
import SwiftUI

struct MessageEditorView: View {

    let existing: Message?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \MessageGroup.createdAt) private var groups: [MessageGroup]

    @State private var title: String
    @State private var text: String
    @State private var contactName: String
    @State private var contactHandle: String
    @State private var contactImageData: Data?
    @State private var contactIdentifier: String
    @State private var frequency: Frequency
    @State private var time: Date
    @State private var weekday: Int
    @State private var monthlyDay: Int
    @State private var yearlyDay: Int
    @State private var yearlyMonth: Int
    @State private var groupID: UUID?

    @State private var resolvedBirthday: DateComponents?
    @State private var birthdayDraft: Date
    @State private var birthdayMonth: Int
    @State private var birthdayDay: Int
    @State private var knowsBirthYear = false
    @State private var savesBirthdayToCard = true

    @State private var isShowingContactPicker = false
    @State private var isAddingGroup = false

    @State private var draft: Message?

    @State private var saveFailure: String?

    init(existing: Message? = nil, group: MessageGroup? = nil) {
        self.existing = existing

        let message = existing
        _groupID = State(initialValue: (existing?.group ?? group)?.identifier)
        _title = State(initialValue: message?.title ?? "")
        _text = State(initialValue: message?.text ?? "")
        _contactName = State(initialValue: message?.contactName ?? "")
        _contactHandle = State(initialValue: message?.contactHandle ?? "")
        _contactImageData = State(initialValue: message?.contactImageData)
        _contactIdentifier = State(initialValue: message?.contactIdentifier ?? "")
        _frequency = State(initialValue: message?.frequency ?? .weekly)
        _weekday = State(initialValue: message?.weekday ?? 2)
        let today = Self.todaysMonthAndDay()
        let isYearly = message?.frequency == .yearly
        _monthlyDay = State(initialValue: isYearly ? 1 : (message?.dayOfMonth ?? 1))
        _yearlyDay = State(initialValue: isYearly ? (message?.dayOfMonth ?? today.day) : today.day)
        _yearlyMonth = State(initialValue: isYearly ? (message?.month ?? today.month) : today.month)

        var components = DateComponents()
        components.hour = message?.hour ?? 9
        components.minute = message?.minute ?? 0
        _time = State(initialValue: Calendar.current.date(from: components) ?? Date())

        let birthday = Self.draftBirthday(for: message)
        _birthdayMonth = State(initialValue: birthday.month)
        _birthdayDay = State(initialValue: birthday.day)

        var birthdayComponents = DateComponents()
        birthdayComponents.year = Calendar.current.component(.year, from: Date())
        birthdayComponents.month = birthday.month
        birthdayComponents.day = birthday.day
        _birthdayDraft = State(initialValue: Calendar.current.date(from: birthdayComponents) ?? Date())
    }

    private static func draftBirthday(for message: Message?) -> (month: Int, day: Int) {
        guard let message, message.frequency == .birthday else { return todaysMonthAndDay() }
        return (message.month, message.dayOfMonth)
    }

    private var canSave: Bool {
        hasContact && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var missingRequirement: String? {
        let hasMessage = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        switch (hasContact, hasMessage) {
        case (true, true): return nil
        case (false, true): return "Choose a contact to save this message."
        case (true, false): return "Write the message you want to send to save it."
        case (false, false): return "Choose a contact and write a message to save it."
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

                            if !hasContact {
                                Text("Choose a contact")
                            } else {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contactName.isEmpty ? contactHandle : contactName)
                                        .foregroundStyle(.primary)
                                    if contactHandle.isEmpty {
                                        Text("No phone or email — you'll get the reminder, and Compose copies the message")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else if !contactName.isEmpty {
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
                    TextEditor(text: $text)
                        .frame(minHeight: Layout.messageEditorMinHeight)
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
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
                } header: {
                    Text("Message")
                }

                Section("Message title") {
                    TextField("Optional, e.g. Check in on Mom", text: $title)
                }

                Section {
                    if !groups.isEmpty {
                        Picker("List", selection: $groupID) {
                            Text("None").tag(UUID?.none)

                            ForEach(groups) { group in
                                Label {
                                    Text(group.name)
                                } icon: {
                                    GroupGlyph(group: group)
                                }
                                .tag(UUID?.some(group.identifier))
                            }
                        }
                    }

                    Button {
                        isAddingGroup = true
                    } label: {
                        Label("New List", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("List")
                } footer: {
                    if groups.isEmpty {
                        Text("Lists keep related messages together — birthdays, friends and family, work. A message doesn't need one.")
                    }
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
            .task { await loadBirthday() }
            .onChange(of: yearlyMonth) { clampYearlyDay() }
            .onChange(of: birthdayMonth) { clampBirthdayDay() }
            .onChange(of: knowsBirthYear) { _, includesYear in
                syncBirthdayDraft(includingYear: includesYear)
            }
            .navigationTitle(existing == nil ? "New Message" : "Edit Message")
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
                    contactIdentifier = selection.identifier

                    // Clear the old photo first so an unphotographed contact
                    // doesn't briefly wear the previous one's face.
                    contactImageData = nil
                    resolvedBirthday = nil
                    let identifier = selection.identifier
                    Task {
                        contactImageData = await ContactPhotoStore
                            .thumbnail(forContactIdentifier: identifier)
                    }
                    Task { await loadBirthday() }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $isAddingGroup) {
                GroupEditorView { groupID = $0.identifier }
            }
            .alert("Couldn't save this message", isPresented: Binding(
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
            case .birthday:
                // Whose birthday isn't known until a contact is chosen; the
                // footer asks for one instead.
                if hasContact && resolvedBirthday == nil {
                    if knowsBirthYear {
                        DatePicker(
                            "Birthday",
                            selection: $birthdayDraft,
                            in: Self.earliestBirthday...Date(),
                            displayedComponents: .date
                        )
                    } else {
                        Picker("Month", selection: $birthdayMonth) {
                            ForEach(1...12, id: \.self) { value in
                                Text(Frequency.monthName(value)).tag(value)
                            }
                        }
                        Picker("Day", selection: $birthdayDay) {
                            ForEach(1...Frequency.lastSelectableDay(inMonth: birthdayMonth), id: \.self) { day in
                                Text(Frequency.ordinal(day)).tag(day)
                            }
                        }
                    }

                    Toggle("Include birth year", isOn: $knowsBirthYear)

                    Toggle("Add to \(possessiveName) card", isOn: $savesBirthdayToCard)
                }
            }
        } header: {
            Text("When")
        } footer: {
            if let scheduleNote {
                Text(scheduleNote)
            }
        }
    }

    private var hasContact: Bool {
        !contactHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !contactIdentifier.isEmpty
    }

    private var firstName: String? {
        let first = contactName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .first
            .map(String.init)

        return first?.isEmpty == false ? first : nil
    }

    private var possessiveName: String {
        firstName.map { "\($0)'s" } ?? "their"
    }

    private var scheduleNote: String? {
        guard frequency == .birthday else { return dayCapNote }

        guard hasContact else {
            return "Choose a contact above, and this sends on their birthday every year."
        }

        let name = firstName ?? "This contact"

        guard let birthday = resolvedBirthday, let date = birthday.recurringMonthAndDay else {
            return """
                \(name) doesn't have a birthday on their contact card yet.

                Birthdays live on the contact card in Contacts. Adding one there means this app, Calendar, and anything else on your iPhone can use it.
                """
        }

        return "Sends every \(Frequency.monthName(date.month)) \(Frequency.ordinal(date.day)), \(possessiveName) birthday."
    }

    private var dayCapNote: String? {
        switch frequency {
        case .daily, .weekly, .birthday:
            nil
        case .monthly:
            "Capped at the 28th so the message sends in every month."
        case .yearly:
            yearlyMonth == 2 ? "Capped at the 28th so the message sends in every year." : nil
        }
    }

    private static func todaysMonthAndDay() -> (month: Int, day: Int) {
        let components = Calendar.current.dateComponents([.month, .day], from: Date())
        let month = components.month ?? 1
        let day = min(components.day ?? 1, Frequency.lastSelectableDay(inMonth: month))
        return (month, day)
    }

    private func loadBirthday() async {
        let identifier = contactIdentifier
        guard !identifier.isEmpty else { return }

        let birthday = await ContactBirthdayStore.birthday(forContactIdentifier: identifier)
        guard identifier == contactIdentifier else { return }

        resolvedBirthday = birthday
    }

    private func syncBirthdayDraft(includingYear: Bool) {
        let calendar = Calendar.current

        guard includingYear else {
            let components = calendar.dateComponents([.month, .day], from: birthdayDraft)
            birthdayMonth = components.month ?? birthdayMonth
            birthdayDay = components.day ?? birthdayDay
            return
        }

        var components = DateComponents()
        components.year = calendar.component(.year, from: Date())
        components.month = birthdayMonth
        components.day = birthdayDay

        guard let date = calendar.date(from: components) else { return }

        birthdayDraft = date > Date()
            ? calendar.date(byAdding: .year, value: -1, to: date) ?? date
            : date
    }

    private func clampBirthdayDay() {
        let lastDay = Frequency.lastSelectableDay(inMonth: birthdayMonth)
        if birthdayDay > lastDay {
            birthdayDay = lastDay
        }
    }

    private func clampYearlyDay() {
        let lastDay = Frequency.lastSelectableDay(inMonth: yearlyMonth)
        if yearlyDay > lastDay {
            yearlyDay = lastDay
        }
    }

    private static let earliestBirthday: Date = {
        Calendar.current.date(byAdding: .year, value: -130, to: Date()) ?? .distantPast
    }()

    private var draftBirthdayComponents: DateComponents {
        guard knowsBirthYear else {
            var components = DateComponents()
            components.month = birthdayMonth
            components.day = birthdayDay
            return components
        }

        return Calendar.current.dateComponents([.year, .month, .day], from: birthdayDraft)
    }

    private var birthdayMonthAndDay: (month: Int, day: Int)? {
        (resolvedBirthday ?? draftBirthdayComponents).recurringMonthAndDay
    }

    private var shouldAddBirthdayToCard: Bool {
        frequency == .birthday
            && resolvedBirthday == nil
            && savesBirthdayToCard
            && !contactIdentifier.isEmpty
    }

    private func save() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let message = existing ?? draft ?? Message()

        message.title = title
        message.text = text
        message.contactName = contactName
        message.contactHandle = contactHandle
        message.contactImageData = contactImageData
        message.contactIdentifier = contactIdentifier
        message.frequency = frequency
        message.hour = components.hour ?? 9
        message.minute = components.minute ?? 0
        message.weekday = weekday
        message.group = groups.first { $0.identifier == groupID }

        if frequency == .birthday, let birthday = birthdayMonthAndDay {
            message.month = birthday.month
            message.dayOfMonth = birthday.day
        } else {
            message.dayOfMonth = frequency == .yearly ? yearlyDay : monthlyDay
            message.month = yearlyMonth
        }

        if existing == nil && draft == nil {
            modelContext.insert(message)
        }

        do {
            try modelContext.save()
        } catch {
            saveFailure = error.localizedDescription
            return
        }

        draft = message

        let identifier = message.notificationIdentifier
        let schedule = message.schedule
        Task { await NotificationScheduler.reschedule(identifier: identifier, schedule: schedule) }

        guard shouldAddBirthdayToCard else {
            dismiss()
            return
        }

        let birthday = draftBirthdayComponents
        let contact = contactIdentifier

        Task {
            do {
                try await ContactBirthdayStore.setBirthday(birthday, forContactIdentifier: contact)
                dismiss()
            } catch {
                saveFailure = error.localizedDescription
            }
        }
    }
}
