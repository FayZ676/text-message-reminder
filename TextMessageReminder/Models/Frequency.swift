import Foundation

enum Frequency: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }

    func dateComponents(hour: Int, minute: Int, weekday: Int, dayOfMonth: Int, month: Int) -> DateComponents {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        switch self {
        case .daily:
            break
        case .weekly:
            components.weekday = weekday
        case .monthly:
            components.day = dayOfMonth
        case .yearly:
            components.month = month
            components.day = dayOfMonth
        }

        return components
    }

    func summary(hour: Int, minute: Int, weekday: Int, dayOfMonth: Int, month: Int) -> String {
        let time = Self.timeString(hour: hour, minute: minute)

        switch self {
        case .daily:
            return "Every day at \(time)"
        case .weekly:
            return "Every \(Self.weekdayName(weekday)) at \(time)"
        case .monthly:
            return "On the \(Self.ordinal(dayOfMonth)) at \(time)"
        case .yearly:
            return "Every \(Self.monthName(month)) \(Self.ordinal(dayOfMonth)) at \(time)"
        }
    }

    static func timeString(hour: Int, minute: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        guard let date = Calendar.current.date(from: components) else {
            return String(format: "%02d:%02d", hour, minute)
        }

        return date.formatted(date: .omitted, time: .shortened)
    }

    static func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let index = weekday - 1
        guard symbols.indices.contains(index) else { return "Sunday" }
        return symbols[index]
    }

    static func monthName(_ month: Int) -> String {
        let symbols = Calendar.current.monthSymbols
        let index = month - 1
        guard symbols.indices.contains(index) else { return "January" }
        return symbols[index]
    }

    static func lastSelectableDay(inMonth month: Int) -> Int {
        switch month {
        case 2: return 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    static func ordinal(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
