import ContactsUI
import SwiftUI

struct ContactSelection: Equatable {
    let name: String
    let handle: String

    /// The address book's own id, so a photo can be fetched separately. The
    /// picker's `CNContact` is partially fetched and can't carry one itself.
    let identifier: String
}

struct ContactPickerView: UIViewControllerRepresentable {

    var onComplete: (ContactSelection?) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator

        // Every contact stays pickable, including friends reached only through
        // other apps; a contact without a number or email still gets reminders.
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey, CNContactEmailAddressesKey]

        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency CNContactPickerDelegate {
        var parent: ContactPickerView

        private var hasCompleted = false

        init(parent: ContactPickerView) {
            self.parent = parent
        }

        private func complete(with selection: ContactSelection?) {
            guard !hasCompleted else { return }
            hasCompleted = true
            parent.onComplete(selection)
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
            let name = CNContactFormatter.string(from: contactProperty.contact, style: .fullName) ?? ""

            let handle: String
            if let phone = contactProperty.value as? CNPhoneNumber {
                handle = phone.stringValue
            } else if let email = contactProperty.value as? String {
                handle = email
            } else {
                handle = ""
            }

            guard !handle.isEmpty else { return }
            complete(with: ContactSelection(
                name: name,
                handle: handle,
                identifier: contactProperty.contact.identifier
            ))
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""

            let handle = contact.phoneNumbers.first?.value.stringValue
                ?? contact.emailAddresses.first?.value as String?
                ?? ""

            complete(with: ContactSelection(
                name: name,
                handle: handle,
                identifier: contact.identifier
            ))
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            complete(with: nil)
        }
    }
}
