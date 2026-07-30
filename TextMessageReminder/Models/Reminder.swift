import Foundation
import SwiftData

@Model
final class Reminder {
    var identifier: UUID

    var title: String

    var message: String

    var usesVariations: Bool

    var contactName: String

    var contactHandle: String

    /// The contact's photo as it looked when they were picked. Snapshotting it
    /// keeps the list rendering from depending on live Contacts permission, at
    /// the cost of going stale if they change their photo later — re-picking the
    /// contact refreshes it.
    var contactImageData: Data?

    var frequencyRaw: String

    var hour: Int
    var minute: Int

    var weekday: Int

    var dayOfMonth: Int

    var month: Int = 1

    var isEnabled: Bool

    var createdAt: Date

    init(
        identifier: UUID = UUID(),
        title: String = "",
        message: String = "",
        usesVariations: Bool = false,
        contactName: String = "",
        contactHandle: String = "",
        contactImageData: Data? = nil,
        frequency: Frequency = .weekly,
        hour: Int = 9,
        minute: Int = 0,
        weekday: Int = 2,
        dayOfMonth: Int = 1,
        month: Int = 1,
        isEnabled: Bool = true,
        createdAt: Date = Date()
    ) {
        self.identifier = identifier
        self.title = title
        self.message = message
        self.usesVariations = usesVariations
        self.contactName = contactName
        self.contactHandle = contactHandle
        self.contactImageData = contactImageData
        self.frequencyRaw = frequency.rawValue
        self.hour = hour
        self.minute = minute
        self.weekday = weekday
        self.dayOfMonth = dayOfMonth
        self.month = month
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }

    var frequency: Frequency {
        get { Frequency(rawValue: frequencyRaw) ?? .weekly }
        set { frequencyRaw = newValue.rawValue }
    }

    var notificationIdentifier: String { identifier.uuidString }

    var frequencySummary: String {
        frequency.summary(hour: hour, minute: minute, weekday: weekday, dayOfMonth: dayOfMonth, month: month)
    }

    var triggerComponents: DateComponents {
        frequency.dateComponents(hour: hour, minute: minute, weekday: weekday, dayOfMonth: dayOfMonth, month: month)
    }

    var isComplete: Bool {
        !contactHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var schedule: ReminderSchedule? {
        guard isEnabled, isComplete else { return nil }
        return ReminderSchedule(
            identifier: notificationIdentifier,
            title: effectiveTitle,
            body: message,
            components: triggerComponents
        )
    }

    var effectiveTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return contactName.isEmpty ? "Send a message" : "Text \(contactName)"
    }
}
