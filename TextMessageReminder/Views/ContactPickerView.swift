import ContactsUI
import SwiftUI

struct ContactSelection: Equatable {
    let name: String
    let handle: String
}

struct ContactPickerView: UIViewControllerRepresentable {

    var onComplete: (ContactSelection?) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator

        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey, CNContactEmailAddressesKey]
        picker.predicateForEnablingContact = NSPredicate(
            format: "phoneNumbers.@count > 0 OR emailAddresses.@count > 0"
        )

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
            complete(with: ContactSelection(name: name, handle: handle))
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""

            let handle = contact.phoneNumbers.first?.value.stringValue
                ?? contact.emailAddresses.first?.value as String?
                ?? ""

            guard !handle.isEmpty else { return }
            complete(with: ContactSelection(name: name, handle: handle))
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            complete(with: nil)
        }
    }
}
