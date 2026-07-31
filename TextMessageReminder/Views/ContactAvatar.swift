import SwiftUI

/// The person a message is about: their contact photo when we have one, their
/// initials when we don't. Purely decorative — every place it appears already
/// names the contact in text, so it stays out of the accessibility tree.
struct ContactAvatar: View {

    let name: String
    let handle: String
    let imageData: Data?

    var diameter: CGFloat = Layout.avatarDiameter

    var body: some View {
        ZStack {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                monogram
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }

    private var monogram: some View {
        ZStack {
            Color.accentColor.opacity(0.15)

            if let initials {
                Text(initials)
                    .font(.system(size: diameter * 0.4, weight: .semibold))
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: diameter * 0.45))
            }
        }
        .foregroundStyle(Color.accentColor)
    }

    /// Up to two initials from the contact's name, falling back to the handle's
    /// first letter for an email address. A phone number has no letter to take,
    /// and a digit in a monogram just reads as a bug — the glyph is better.
    private var initials: String? {
        let letters = name
            .split(whereSeparator: \.isWhitespace)
            .compactMap { $0.first(where: \.isLetter) }
            .prefix(2)

        if !letters.isEmpty { return String(letters).uppercased() }

        guard let first = handle.first, first.isLetter else { return nil }
        return String(first).uppercased()
    }
}

#Preview {
    VStack(spacing: Layout.regular) {
        ContactAvatar(name: "Ada Lovelace", handle: "+15551234567", imageData: nil)
        ContactAvatar(name: "", handle: "ada@example.com", imageData: nil)
        ContactAvatar(name: "", handle: "+15551234567", imageData: nil)
    }
    .padding()
}
