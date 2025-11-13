import SwiftUI
import Contacts
import UIKit

struct MemoryPersonTriggerEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    private let showsCloseButton: Bool
    @State private var name: String
    @State private var contactIdentifier: String
    @State private var showContactPicker = false
    @State private var showAccessDeniedAlert = false

    private var existingTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .person })
    }

    init(viewModel: MemoryEditorViewModel, showsCloseButton: Bool = true) {
        self.viewModel = viewModel
        self.showsCloseButton = showsCloseButton
        let trigger = viewModel.triggers.first(where: { $0.type == .person })
        _name = State(initialValue: trigger?.person?.name ?? "")
        _contactIdentifier = State(initialValue: trigger?.person?.contactIdentifier ?? "")
    }

    var body: some View {
        Form {
            Section("Contact") {
                HStack {
                    TextField("Name", text: $name)
                    Button {
                        Task { await requestContactsAndShow() }
                    } label: {
                        Image(systemName: "person.crop.circle.badge.plus")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Pick from contacts")
                }

                if !contactIdentifier.isEmpty {
                    Label("Contact linked", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Section {
                Text("Enter a name or choose from contacts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(existingTrigger == nil ? "Add Person Trigger" : "Edit Person Trigger")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: dismiss.callAsFunction) {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm, action: commitChanges) {
                    Image(systemName: confirmationIconName)
                }
                .accessibilityLabel(confirmationAccessibilityLabel)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if existingTrigger != nil {
                    Button(role: .destructive, action: removeTrigger) {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Remove person trigger")
                }
            }
        }
        .sheet(isPresented: $showContactPicker) {
            ContactPickerView { selectedName, identifier in
                name = selectedName
                contactIdentifier = identifier ?? ""
                showContactPicker = false
            }
        }
        .alert("Contacts Access Required", isPresented: $showAccessDeniedAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Allow contact access in Settings to pick a person trigger.")
        }
    }

    private func commitChanges() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if let trigger = existingTrigger {
            var updated = trigger
            updated.person = .init(
                name: trimmedName,
                contactIdentifier: contactIdentifier.isEmpty ? nil : contactIdentifier
            )
            viewModel.updateTrigger(id: trigger.id, with: updated)
        } else {
            viewModel.addPersonTrigger(
                name: trimmedName,
                identifier: contactIdentifier.isEmpty ? nil : contactIdentifier
            )
        }
        dismiss()
    }

    private func requestContactsAndShow() async {
        let status = ContactAccessHelper.checkAuthorizationStatus()
        switch status {
        case .authorized, .limited:
            await MainActor.run {
                showContactPicker = true
            }
        case .notDetermined:
            let granted = await ContactAccessHelper.requestAccess()
            await MainActor.run {
                if granted {
                    showContactPicker = true
                } else {
                    showAccessDeniedAlert = true
                }
            }
        case .denied, .restricted:
            await MainActor.run {
                showAccessDeniedAlert = true
            }
        @unknown default:
            await MainActor.run {
                showAccessDeniedAlert = true
            }
        }
    }

    private var confirmationIconName: String { "checkmark" }

    private var confirmationAccessibilityLabel: String {
        existingTrigger == nil ? "Add" : "Save"
    }

    private func removeTrigger() {
        guard let trigger = existingTrigger else { return }
        viewModel.removeTrigger(id: trigger.id)
        dismiss()
    }
}
