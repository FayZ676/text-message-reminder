import Foundation
import UserNotifications

@MainActor
final class NotificationCoordinator: NSObject, ObservableObject {

    /// The delegate has to be registered at launch, before any view exists, so
    /// the instance the app delegate reaches for and the one the list observes
    /// have to be the same object.
    static let shared = NotificationCoordinator()

    /// Set when a notification is tapped, cleared once Messages has been opened
    /// for it. It outlives the tap on purpose: a cold launch resolves the tap
    /// before the list exists, and the list claims it when it appears.
    @Published var pendingMessageID: UUID?

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
        // Tapping the banner itself is the default action, and it should land in
        // Messages exactly like the Compose button does. Dismissing shouldn't.
        guard
            response.actionIdentifier == UNNotificationDefaultActionIdentifier
                || response.actionIdentifier == NotificationScheduler.composeActionIdentifier
        else { return }

        let userInfo = response.notification.request.content.userInfo

        guard
            let raw = userInfo[NotificationScheduler.messageIDKey] as? String,
            let id = UUID(uuidString: raw)
        else { return }

        await MainActor.run {
            self.pendingMessageID = id
        }
    }
}
