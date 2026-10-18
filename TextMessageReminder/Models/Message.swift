import Foundation
import SwiftData

@Model
final class Message {
    var identifier: UUID

    var title: String

    var text: String

    var contactName: String

    var contactHandle: String

    /// The contact's photo as it looked when they were picked. Snapshotting it
    /// keeps the list rendering from depending on live Contacts permission, at
    /// the cost of going stale if they change their photo later — re-picking the
    /// contact refreshes it.
    var contactImageData: Data?

    var contactIdentifier: String = ""

    var frequencyRaw: String

    var hour: Int
    var minute: Int

    var weekday: Int

    var dayOfMonth: Int

    var month: Int = 1

    var isEnabled: Bool

    var createdAt: Date

    var group: MessageGroup?

    init(
        identifier: UUID = UUID(),
        title: String = "",
        text: String = "",
        contactName: String = "",
        contactHandle: String = "",
        contactImageData: Data? = nil,
        contactIdentifier: String = "",
        frequency: Frequency = .weekly,
        hour: Int = 9,
        minute: Int = 0,
        weekday: Int = 2,
        dayOfMonth: Int = 1,
        month: Int = 1,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        group: MessageGroup? = nil
    ) {
        self.identifier = identifier
        self.title = title
        self.text = text
        self.contactName = contactName
        self.contactHandle = contactHandle
        self.contactImageData = contactImageData
        self.contactIdentifier = contactIdentifier
        self.frequencyRaw = frequency.rawValue
        self.hour = hour
        self.minute = minute
        self.weekday = weekday
        self.dayOfMonth = dayOfMonth
        self.month = month
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.group = group
    }

    var frequency: Frequency {
        get { Frequency(rawValue: frequencyRaw) ?? .weekly }
        set { frequencyRaw = newValue.rawValue }
    }

    var notificationIdentifier: String { identifier.uuidString }

    /// When this message next comes due. Matching is strict so a day a month
    /// lacks (a Feb 29 birthday) is skipped, just as the notification trigger
    /// skips it.
    func nextFireDate(after date: Date) -> Date? {
        Calendar.current.nextDate(after: date, matching: triggerComponents, matchingPolicy: .strict)
    }

    func nextFireSummary(after now: Date) -> String {
        guard let next = nextFireDate(after: now) else { return "Not scheduled" }

        var style = Date.FormatStyle()
            .weekday(.abbreviated).month(.abbreviated).day()
            .hour().minute()
        if !Calendar.current.isDate(next, equalTo: now, toGranularity: .year) {
            style = style.year()
        }

        return next.formatted(style)
    }

    var triggerComponents: DateComponents {
        frequency.dateComponents(hour: hour, minute: minute, weekday: weekday, dayOfMonth: dayOfMonth, month: month)
    }

    /// A contact without a phone number or email still counts: the reminder is
    /// worth having even when the conversation happens in another app.
    var hasContact: Bool {
        !contactHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !contactIdentifier.isEmpty
    }

    var isComplete: Bool {
        hasContact && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var schedule: MessageSchedule? {
        guard isEnabled, isComplete else { return nil }
        return MessageSchedule(
            identifier: notificationIdentifier,
            title: effectiveTitle,
            body: text,
            components: triggerComponents
        )
    }

    var effectiveTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return contactName.isEmpty ? "Send a message" : "Text \(contactName)"
    }
}
