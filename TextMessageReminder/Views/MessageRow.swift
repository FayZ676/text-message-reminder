import SwiftUI

struct MessageRow: View {
    let message: Message
    let isGenerating: Bool
    let onCompose: () -> Void

    private var summary: String {
        var parts: [String] = []

        if !message.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(message.contactName.isEmpty ? message.contactHandle : message.contactName)
        }

        parts.append(message.frequencySummary)

        if !message.isEnabled { parts.append("Paused") }

        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .center, spacing: Layout.regular) {
            ContactAvatar(
                name: message.contactName,
                handle: message.contactHandle,
                imageData: message.contactImageData,
                diameter: Layout.listRowIconDiameter
            )

            content
        }
        .opacity(message.isEnabled ? 1 : 0.5)
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
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

            Text(summary)
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

    private var composeButton: some View {
        Button(action: onCompose) {
            Group {
                if isGenerating {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: "paperplane.circle.fill")
                        .font(.headline)
                        .imageScale(.large)
                }
            }
            .frame(width: Layout.iconButtonGlyph)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .disabled(isGenerating)
        .accessibilityLabel(isGenerating ? "Writing message" : "Compose")
    }
}
