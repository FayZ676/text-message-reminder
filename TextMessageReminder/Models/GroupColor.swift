import SwiftUI

enum GroupColor: String, CaseIterable, Identifiable {
    case red
    case orange
    case yellow
    case green
    case mint
    case teal
    case blue
    case indigo
    case purple
    case pink
    case brown
    case gray

    static let fallback = GroupColor.blue

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .brown: .brown
        case .gray: .gray
        }
    }
}

enum GroupSymbol {

    static let fallback = "list.bullet"

    static let all = [
        "list.bullet",
        "birthday.cake.fill",
        "heart.fill",
        "person.2.fill",
        "house.fill",
        "briefcase.fill",
        "star.fill",
        "gift.fill",
        "phone.fill",
        "envelope.fill",
        "calendar",
        "airplane",
        "graduationcap.fill",
        "pawprint.fill",
        "figure.run",
        "cup.and.saucer.fill",
        "music.note",
        "leaf.fill"
    ]
}
