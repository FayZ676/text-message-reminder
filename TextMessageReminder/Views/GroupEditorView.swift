import SwiftData
import SwiftUI

struct GroupEditorView: View {

    let existing: MessageGroup?

    let onSave: (MessageGroup) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var color: GroupColor
    @State private var symbolName: String

    @State private var saveFailure: String?

    init(existing: MessageGroup? = nil, onSave: @escaping (MessageGroup) -> Void = { _ in }) {
        self.existing = existing
        self.onSave = onSave

        _name = State(initialValue: existing?.name ?? "")
        _color = State(initialValue: existing?.color ?? .fallback)
        _symbolName = State(initialValue: existing?.symbolName ?? GroupSymbol.fallback)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Layout.snug), count: 6)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: Layout.regular) {
                        GroupGlyph(
                            symbolName: symbolName,
                            color: color,
                            diameter: Layout.groupGlyphPreviewDiameter
                        )

                        TextField("List name", text: $name)
                            .multilineTextAlignment(.center)
                            .font(.title3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Layout.snug)
                }

                Section("Color") {
                    LazyVGrid(columns: columns, spacing: Layout.snug) {
                        ForEach(GroupColor.allCases) { option in
                            colorSwatch(option)
                        }
                    }
                    .padding(.vertical, Layout.tight)
                }

                Section("Icon") {
                    LazyVGrid(columns: columns, spacing: Layout.snug) {
                        ForEach(GroupSymbol.all, id: \.self) { option in
                            symbolSwatch(option)
                        }
                    }
                    .padding(.vertical, Layout.tight)
                }

                if !canSave {
                    Section {
                        EmptyView()
                    } footer: {
                        Label("Name this list to save it.", systemImage: "exclamationmark.circle")
                    }
                }
            }
            .navigationTitle(existing == nil ? "New List" : "Edit List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .alert("Couldn't save this list", isPresented: Binding(
                get: { saveFailure != nil },
                set: { if !$0 { saveFailure = nil } }
            )) {
                Button("OK") { saveFailure = nil }
            } message: {
                Text(saveFailure ?? "")
            }
        }
    }

    private func colorSwatch(_ option: GroupColor) -> some View {
        Button {
            color = option
        } label: {
            Circle()
                .fill(option.color)
                .frame(width: Layout.swatchDiameter, height: Layout.swatchDiameter)
                .overlay {
                    Circle()
                        .strokeBorder(Color.primary, lineWidth: 2)
                        .padding(-Layout.tight / 2)
                        .opacity(option == color ? 1 : 0)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.displayName)
        .accessibilityAddTraits(option == color ? [.isSelected] : [])
    }

    private func symbolSwatch(_ option: String) -> some View {
        Button {
            symbolName = option
        } label: {
            ZStack {
                Circle().fill(option == symbolName ? color.color : Color.secondary.opacity(0.15))

                Image(systemName: option)
                    .font(.system(size: Layout.swatchDiameter * 0.45))
                    .foregroundStyle(option == symbolName ? .white : .primary)
            }
            .frame(width: Layout.swatchDiameter, height: Layout.swatchDiameter)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option)
        .accessibilityAddTraits(option == symbolName ? [.isSelected] : [])
    }

    private func save() {
        let group = existing ?? MessageGroup()

        group.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        group.color = color
        group.symbolName = symbolName

        if existing == nil {
            modelContext.insert(group)
        }

        do {
            try modelContext.save()
        } catch {
            saveFailure = error.localizedDescription
            return
        }

        onSave(group)
        dismiss()
    }
}
