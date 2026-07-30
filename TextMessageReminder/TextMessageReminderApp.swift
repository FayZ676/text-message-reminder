import SwiftData
import SwiftUI
import UserNotifications

@main
struct TextMessageReminderApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var coordinator = NotificationCoordinator.shared

    private static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-uitesting")
    }

    var body: some Scene {
        WindowGroup {
            ReminderListView()
                .environmentObject(coordinator)
        }
        .modelContainer(for: Reminder.self, inMemory: Self.isUITesting)
    }
}

/// A notification tap only reaches a delegate that was already in place when the
/// app finished launching. Registering from a SwiftUI `.task` runs a render too
/// late, so a cold launch from a notification dropped the tap and left the user
/// looking at the list instead of at Messages.
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        MainActor.assumeIsolated { NotificationCoordinator.shared.start() }
        return true
    }
}
