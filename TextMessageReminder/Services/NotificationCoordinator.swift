import Foundation
import UserNotifications

@MainActor
final class NotificationCoordinator: NSObject, ObservableObject {

    @Published var pendingReminderID: UUID?

    func start() {
        UNUserNotificationCenter.current().delegate = self
        NotificationScheduler.registerCategory()
    }
}

extension NotificationCoordinator: UNUserNotificationCenterDelegate {

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo

        guard
            let raw = userInfo[NotificationScheduler.reminderIDKey] as? String,
            let id = UUID(uuidString: raw)
        else { return }

        await MainActor.run {
            self.pendingReminderID = id
        }
    }
}
