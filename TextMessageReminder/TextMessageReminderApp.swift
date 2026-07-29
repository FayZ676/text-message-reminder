import SwiftData
import SwiftUI

@main
struct TextMessageReminderApp: App {

    @StateObject private var coordinator = NotificationCoordinator()

    private static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-uitesting")
    }

    var body: some Scene {
        WindowGroup {
            ReminderListView()
                .environmentObject(coordinator)
                .task { coordinator.start() }
        }
        .modelContainer(for: Reminder.self, inMemory: Self.isUITesting)
    }
}
