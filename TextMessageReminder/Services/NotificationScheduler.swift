import Foundation
import UserNotifications

struct MessageSchedule: Sendable, Equatable {
    let identifier: String
    let title: String
    let body: String
    let components: DateComponents
}

enum NotificationScheduler {

    static let categoryIdentifier = "MESSAGE"
    static let composeActionIdentifier = "COMPOSE"
    static let messageIDKey = "messageID"

    private static var center: UNUserNotificationCenter { .current() }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func registerCategory() {
        let compose = UNNotificationAction(
            identifier: composeActionIdentifier,
            title: "Compose",
            options: [.foreground]
        )

        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [compose],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([category])
    }

    static func schedule(_ schedule: MessageSchedule) async {
        let content = UNMutableNotificationContent()
        content.title = schedule.title
        content.body = schedule.body
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = [messageIDKey: schedule.identifier]

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: schedule.components,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: schedule.identifier,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    static func cancel(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    static func reschedule(identifier: String, schedule: MessageSchedule?) async {
        cancel(identifier: identifier)
        guard let schedule else { return }
        await self.schedule(schedule)
    }

    static func syncAll(_ schedules: [MessageSchedule]) async {
        let pending = await center.pendingNotificationRequests()
        let liveIdentifiers = Set(schedules.map(\.identifier))

        let orphaned = pending.map(\.identifier).filter { !liveIdentifiers.contains($0) }
        if !orphaned.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: orphaned)
        }

        for schedule in schedules {
            await reschedule(identifier: schedule.identifier, schedule: schedule)
        }
    }

    static func pendingIdentifiers() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }
}
