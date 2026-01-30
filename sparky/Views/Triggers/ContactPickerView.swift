//
//  ContactPickerView.swift
//  sparky
//
//  Created by Codex on 13/10/25.
//

import SwiftUI
import ContactsUI
import Contacts

struct ContactPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onContactSelected: (String, String?) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey, CNContactEmailAddressesKey]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onContactSelected: onContactSelected)
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        let onContactSelected: (String, String?) -> Void

        init(onContactSelected: @escaping (String, String?) -> Void) {
            self.onContactSelected = onContactSelected
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let fullName = [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            onContactSelected(fullName, contact.identifier)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            // User cancelled selection
        }
    }
}

struct ContactAccessHelper {
    static func requestAccess() async -> Bool {
        let store = CNContactStore()

        do {
            let granted = try await store.requestAccess(for: .contacts)
            return granted
        } catch {
            print("Error requesting contacts access: \(error)")
            return false
        }
    }

    static func checkAuthorizationStatus() -> CNAuthorizationStatus {
        return CNContactStore.authorizationStatus(for: .contacts)
    }
}
