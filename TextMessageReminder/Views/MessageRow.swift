import SwiftUI

struct MessageRow: View {
    let message: Message
    let now: Date
    let onCompose: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Layout.regular) {
            ContactAvatar(
                name: message.contactName,
                handle: message.contactHandle,
                imageData: message.contactImageData,
                diameter: Layout.listRowIconDiameter
            )

            content
                .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
        }
        .opacity(message.isEnabled ? 1 : 0.5)
        .listRowInsets(EdgeInsets(
            top: Layout.regular,
            leading: Layout.gutter,
            bottom: Layout.regular,
            trailing: Layout.gutter
        ))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Layout.tight) {
            HStack(alignment: .center, spacing: Layout.snug) {
                Text(message.effectiveTitle)
                    .font(.headline)

                Spacer(minLength: Layout.snug)

                composeButton

                disclosureChevron
            }

            Text(message.text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(message.nextFireSummary(after: now))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var disclosureChevron: some View {
        Image(systemName: "chevron.forward")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }

    /// No phone number or email means there's nothing for Messages to open, so
    /// the button copies instead — and says so with its glyph.
    private var copiesInstead: Bool {
        MessagesLink.composeURL(for: message) == nil
    }

    private var composeButton: some View {
        Button(action: onCompose) {
            Group {
                if copiesInstead {
                    // There's no circled copy symbol, so it's built from the same
                    // `circle.fill` the paper plane sits in, keeping both the same size.
                    Image(systemName: "circle.fill")
                        .overlay {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                } else {
                    Image(systemName: "paperplane.circle.fill")
                }
            }
            .font(.headline)
            .imageScale(.large)
            .frame(width: Layout.iconButtonGlyph)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .accessibilityLabel(copiesInstead ? "Copy message" : "Compose")
    }
}
