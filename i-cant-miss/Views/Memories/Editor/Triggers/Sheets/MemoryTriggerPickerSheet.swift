import SwiftUI

struct MemoryTriggerPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    @State private var selectedDestination: MemoryTriggerPickerDestination?

    var body: some View {
        NavigationStack {
            List {
                Section("Date & Time") {
                    TriggerPickerRow(
                        title: "Exact time",
                        subtitle: exactTimeSubtitle,
                        systemImage: "alarm",
                        isActive: isExactTimeActive
                    ) {
                        select(.exactTime)
                    }
                    TriggerPickerRow(
                        title: "Weekday routine",
                        subtitle: weekdaySubtitle,
                        systemImage: "calendar.badge.clock",
                        isActive: isWeekdayRoutineActive
                    ) {
                        select(.weekdayRoutine)
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
                case .exactTime:
                    MemoryExactTimeTriggerEditorScreen(viewModel: viewModel, showsCloseButton: false)
                case .weekdayRoutine:
                    MemoryWeekdayTriggerEditorScreen(viewModel: viewModel, showsCloseButton: false)
                case .location:
                    MemoryLocationTriggerEditorScreen(viewModel: viewModel, showsCloseButton: false)
                case .person:
                    MemoryPersonTriggerEditorScreen(viewModel: viewModel, showsCloseButton: false)
                case .sequential:
                    MemorySequentialTriggerEditorScreen(
                        viewModel: viewModel,
                        excludedMemoryID: viewModel.editingMemoryID,
                        showsCloseButton: false
                    )
                }
            }
        }
    }

    private var isExactTimeActive: Bool {
        viewModel.triggers.contains(where: { $0.type == .time })
    }

    private var isWeekdayRoutineActive: Bool {
        viewModel.triggers.contains(where: { $0.type == .dayOfWeek })
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

    private var exactTimeSubtitle: String {
        if isExactTimeActive {
            return "Update the existing exact time trigger."
        }
        return "Schedule a specific date and time with optional repeats."
    }

    private var weekdaySubtitle: String {
        if isWeekdayRoutineActive {
            return "Modify the current weekday routine."
        }
        return "Pick days of the week to repeat this memory."
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

    private func select(_ destination: MemoryTriggerPickerDestination) {
        selectedDestination = destination
    }
}
