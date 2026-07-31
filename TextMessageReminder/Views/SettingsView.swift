import SwiftUI

struct SettingsView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var apiKey: String = ""
    @State private var hasStoredKey: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-ant-…", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Anthropic API key")
                } footer: {
                    Text("Needed only for messages with \"Vary this message\" turned on. Create a key at console.anthropic.com. It's stored in your device's keychain, and any messages rewritten are billed to it.")
                }

                if hasStoredKey {
                    Section {
                        Button("Remove key", role: .destructive) {
                            KeychainStore.setAPIKey(nil)
                            apiKey = ""
                            hasStoredKey = false
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        KeychainStore.setAPIKey(apiKey)
                        dismiss()
                    }
                }
            }
            .task {
                apiKey = KeychainStore.apiKey() ?? ""
                hasStoredKey = !apiKey.isEmpty
            }
        }
    }
}
