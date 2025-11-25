import SwiftUI

struct TriggerPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    @State private var selectedDestination: MemoryTriggerPickerDestination?

    var body: some View {
        NavigationStack {
            List {
                Section("Date & Time") {
                    TriggerPickerRow(
                        title: "Date & Time",
                        subtitle: dateAndTimeSubtitle,
                        systemImage: "clock.badge",
                        isActive: isDateAndTimeActive
                    ) {
                        select(.dateAndTime)
                    }
                }

                Section("Location") {
                    TriggerPickerRow(
                        title: "Location trigger",
                        subtitle: locationSubtitle,
                        systemImage: "mappin.circle.fill",
                        isActive: isLocationActive
                    ) {
                        select(.location)
                    }
                }

                Section("Person") {
                    TriggerPickerRow(
                        title: "Person trigger",
                        subtitle: personSubtitle,
                        systemImage: "person.crop.circle.badge.plus",
                        isActive: isPersonActive
                    ) {
                        select(.person)
                    }
                }

                Section("Sequence") {
                    TriggerPickerRow(
                        title: "Sequential trigger",
                        subtitle: sequentialSubtitle,
                        systemImage: "arrow.right",
                        isActive: isSequentialActive
                    ) {
                        select(.sequential)
                    }
                }

                Section("Focus") {
                    TriggerPickerRow(
                        title: "Focus trigger",
                        subtitle: focusSubtitle,
                        systemImage: "moon.fill",
                        isActive: isFocusActive
                    ) {
                        select(.focus)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add Trigger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Close")
                }
            }
            .navigationDestination(item: $selectedDestination) { destination in
                switch destination {
                case .dateAndTime:
                    ScheduledTriggerEditorScreen(viewModel: viewModel, showsCloseButton: false)
                case .location:
                    LocationTriggerEditorScreen(viewModel: viewModel, showsCloseButton: false)
                case .person:
                    PersonTriggerEditorScreen(viewModel: viewModel, showsCloseButton: false)
                case .sequential:
                    SequentialTriggerEditorScreen(
                        viewModel: viewModel,
                        excludedMemoryID: viewModel.editingMemoryID,
                        showsCloseButton: false
                    )
                case .focus:
                    FocusTriggerEditorScreen(viewModel: viewModel, showsCloseButton: false)
                }
            }
        }
    }

    private var isDateAndTimeActive: Bool {
        viewModel.triggers.contains(where: { $0.type == .scheduled })
    }

    private var isLocationActive: Bool {
        viewModel.triggers.contains(where: { $0.type == .location })
    }

    private var isPersonActive: Bool {
        viewModel.triggers.contains(where: { $0.type == .person })
    }

    private var isSequentialActive: Bool {
        viewModel.sequentialTrigger != nil
    }

    private var isFocusActive: Bool {
        viewModel.triggers.contains(where: { $0.type == .focus })
    }

    private var dateAndTimeSubtitle: String {
        if isDateAndTimeActive {
            return "Update the existing date & time trigger."
        }
        return "Schedule a specific date and time with optional repeats and weekday selection."
    }

    private var locationSubtitle: String {
        if isLocationActive {
            return "Edit the existing location reminder."
        }
        return "Be reminded when arriving or leaving a place."
    }

    private var personSubtitle: String {
        if isPersonActive {
            return "Update the person associated with this memory."
        }
        return "Trigger when you interact with someone."
    }

    private var sequentialSubtitle: String {
        if isSequentialActive {
            return "Manage the sequential trigger for this memory."
        }
        return "Link this memory with others to create sequences."
    }

    private var focusSubtitle: String {
        if isFocusActive {
            return "Update the existing focus mode trigger."
        }
        return "Get reminded when you activate a specific focus mode."
    }

    private func select(_ destination: MemoryTriggerPickerDestination) {
        selectedDestination = destination
    }
}
