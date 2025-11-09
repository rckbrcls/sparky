import SwiftUI

struct MemoryTriggerPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                Section("Date & Time") {
                    TriggerPickerRow(
                        title: "Due date",
                        subtitle: dueDateSubtitle,
                        systemImage: "calendar"
                    ) {
                        select(.dueDate)
                    }
                    TriggerPickerRow(
                        title: "Exact time",
                        subtitle: exactTimeSubtitle,
                        systemImage: "alarm"
                    ) {
                        select(.exactTime)
                    }
                    TriggerPickerRow(
                        title: "Weekday routine",
                        subtitle: weekdaySubtitle,
                        systemImage: "calendar.badge.clock"
                    ) {
                        select(.weekdayRoutine)
                    }
                }

                Section("Location") {
                    TriggerPickerRow(
                        title: "Location trigger",
                        subtitle: locationSubtitle,
                        systemImage: "mappin.circle.fill"
                    ) {
                        select(.location)
                    }
                }

                Section("Person") {
                    TriggerPickerRow(
                        title: "Person trigger",
                        subtitle: personSubtitle,
                        systemImage: "person.crop.circle.badge.plus"
                    ) {
                        select(.person)
                    }
                }

                Section("Sequence") {
                    TriggerPickerRow(
                        title: "Sequential trigger",
                        subtitle: "Link this memory with others to create sequences.",
                        systemImage: "arrow.right"
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
                    Button("Close") { dismiss() }
                }
            }
            .navigationDestination(for: MemoryTriggerPickerDestination.self) { destination in
                switch destination {
                case .dueDate:
                    MemoryDueDateTriggerEditorScreen(viewModel: viewModel)
                case .exactTime:
                    MemoryExactTimeTriggerEditorScreen(viewModel: viewModel)
                case .weekdayRoutine:
                    MemoryWeekdayTriggerEditorScreen(viewModel: viewModel)
                case .location:
                    MemoryLocationTriggerEditorScreen(viewModel: viewModel)
                case .person:
                    MemoryPersonTriggerEditorScreen(viewModel: viewModel)
                case .sequential:
                    MemorySequentialTriggerEditorScreen(
                        viewModel: viewModel,
                        excludedMemoryID: viewModel.editingMemoryID
                    )
                }
            }
        }
    }

    private var dueDateSubtitle: String {
        if viewModel.dueDateEnabled {
            return "Edit the due date for this memory."
        }
        return "Convert this memory into a dated checklist."
    }

    private var exactTimeSubtitle: String {
        if viewModel.triggers.contains(where: { $0.type == .time }) {
            return "Update the existing exact time trigger."
        }
        return "Schedule a specific date and time with optional repeats."
    }

    private var weekdaySubtitle: String {
        if viewModel.triggers.contains(where: { $0.type == .dayOfWeek }) {
            return "Modify the current weekday routine."
        }
        return "Pick days of the week to repeat this memory."
    }

    private var locationSubtitle: String {
        if viewModel.triggers.contains(where: { $0.type == .location }) {
            return "Edit the existing location reminder."
        }
        return "Be reminded when arriving or leaving a place."
    }

    private var personSubtitle: String {
        if viewModel.triggers.contains(where: { $0.type == .person }) {
            return "Update the person associated with this memory."
        }
        return "Trigger when you interact with someone."
    }

    private func select(_ destination: MemoryTriggerPickerDestination) {
        navigationPath.append(destination)
    }
}