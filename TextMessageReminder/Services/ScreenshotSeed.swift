#if DEBUG
import SwiftData
import SwiftUI

/// Fills an empty store with believable messages and lists for App Store
/// screenshots. Launched with `-uitesting -screenshots`, so the data lands in
/// the throwaway in-memory store and never touches a real one.
struct ScreenshotSeed: ViewModifier {

    @Environment(\.modelContext) private var modelContext

    private static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-screenshots")
    }

    func body(content: Content) -> some View {
        content.task {
            guard Self.isActive else { return }
            let existing = (try? modelContext.fetchCount(FetchDescriptor<Message>())) ?? 0
            guard existing == 0 else { return }
            seed()
        }
    }

    private func seed() {
        var stamp = Date(timeIntervalSinceNow: -86_400)
        func next() -> Date {
            stamp.addTimeInterval(60)
            return stamp
        }

        let family = MessageGroup(name: "Family", color: .orange, symbolName: "house.fill", createdAt: next())
        let birthdays = MessageGroup(name: "Birthdays", color: .pink, symbolName: "birthday.cake.fill", createdAt: next())
        let friends = MessageGroup(name: "Friends", color: .blue, symbolName: "person.2.fill", createdAt: next())
        [family, birthdays, friends].forEach(modelContext.insert)

        let messages = [
            Message(title: "Call Mom", text: "Hi Mom! Free for a call this afternoon? ❤️",
                    contactName: "Mom", contactHandle: "555-201-4410",
                    frequency: .weekly, hour: 10, weekday: 1, createdAt: next(), group: family),
            Message(title: "Grandpa's garden", text: "Hey Grandpa, how are the tomatoes coming along?",
                    contactName: "Joe Martin", contactHandle: "555-201-7720",
                    frequency: .monthly, hour: 18, dayOfMonth: 1, createdAt: next(), group: family),
            Message(title: "Sarah's birthday", text: "Happy birthday Sarah! 🎉 Hope it's a great one",
                    contactName: "Sarah Chen", contactHandle: "555-318-0042",
                    frequency: .birthday, hour: 9, dayOfMonth: 2, month: 11, createdAt: next(), group: birthdays),
            Message(title: "Marcus's birthday", text: "Happy birthday man! Dinner's on me this weekend 🍕",
                    contactName: "Marcus Lee", contactHandle: "555-318-2290",
                    frequency: .birthday, hour: 9, dayOfMonth: 14, month: 12, createdAt: next(), group: birthdays),
            Message(title: "Priya's birthday", text: "Happy birthday Priya! Miss you, let's catch up soon 💛",
                    contactName: "Priya Patel", contactHandle: "555-318-6631",
                    frequency: .birthday, hour: 9, dayOfMonth: 22, month: 1, createdAt: next(), group: birthdays),
            Message(title: "Pickup basketball", text: "Courts tonight at 7? 🏀",
                    contactName: "Alex Rivera", contactHandle: "555-442-1187",
                    frequency: .weekly, hour: 16, weekday: 5, createdAt: next(), group: friends),
            Message(title: "Good morning", text: "Good morning ☀️ Have a great day!",
                    contactName: "Emily Nguyen", contactHandle: "555-109-3354",
                    frequency: .daily, hour: 8, createdAt: next()),
            Message(title: "Check in with Jordan", text: "How's the new job going? Thinking of you!",
                    contactName: "Jordan Kim", contactHandle: "555-776-5012",
                    frequency: .weekly, hour: 12, weekday: 6, createdAt: next()),
            Message(title: "Rent reminder", text: "Hey Sam! Rent's due today 🏠",
                    contactName: "Sam Torres", contactHandle: "555-776-8820",
                    frequency: .monthly, hour: 9, dayOfMonth: 1, createdAt: next())
        ]
        messages.forEach(modelContext.insert)
        try? modelContext.save()
    }
}
#endif
