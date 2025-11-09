import SwiftUI

struct MemoryTriggerPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    let onSelect: (MemoryTriggerPickerDestination) -> Void

    var body: some View {
        NavigationStack {
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
                        systemImage: "arrowshape.turn.up.right.circle.badge.clockwise"
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
        onSelect(destination)
        dismiss()
    }
}


