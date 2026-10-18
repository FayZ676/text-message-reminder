import SwiftUI

struct GroupGlyph: View {

    let symbolName: String
    let color: GroupColor

    var diameter: CGFloat = Layout.groupGlyphDiameter

    var body: some View {
        ZStack {
            Circle().fill(color.color)

            // Sized as an image, not a font: a font-sized symbol is laid out in
            // a text line box, whose baseline space pushes it off center.
            Image(systemName: symbolName)
                .resizable()
                .scaledToFit()
                .frame(width: diameter * 0.5, height: diameter * 0.5)
                .foregroundStyle(.white)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}

extension GroupGlyph {
    init(group: MessageGroup, diameter: CGFloat = Layout.groupGlyphDiameter) {
        self.init(symbolName: group.symbolName, color: group.color, diameter: diameter)
    }
}

#Preview {
    HStack(spacing: Layout.regular) {
        GroupGlyph(symbolName: "birthday.cake.fill", color: .pink)
        GroupGlyph(symbolName: "heart.fill", color: .red)
        GroupGlyph(
            symbolName: "briefcase.fill",
            color: .indigo,
            diameter: Layout.groupGlyphPreviewDiameter
        )
    }
    .padding()
}
