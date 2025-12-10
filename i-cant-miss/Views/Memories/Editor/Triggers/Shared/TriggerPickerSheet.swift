import SwiftUI

struct TriggerPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    @State private var selectedDestination: MemoryTriggerPickerDestination?

    var body: some View {
        NavigationStack {
            List {
                triggerRow(
                    title: "Date & Time",
                    icon: "clock.badge",
                    isActive: isDateAndTimeActive
                ) {
                    select(.dateAndTime)
                }

                triggerRow(
                    title: "Location",
                    icon: "mappin.circle.fill",
                    isActive: isLocationActive
                ) {
                    select(.location)
                }

                triggerRow(
                    title: "Person",
                    icon: "person.crop.circle.badge.plus",
                    isActive: isPersonActive
                ) {
                    select(.person)
                }

                triggerRow(
                    title: "Sequence",
                    icon: "arrow.right",
                    isActive: isSequentialActive
                ) {
                    select(.sequential)
                }

                triggerRow(
                    title: "Focus",
                    icon: "moon.fill",
                    isActive: isFocusActive
                ) {
                    select(.focus)
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
                            .font(.body.weight(.semibold))
                            .foregroundColor(.secondary)
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
        .presentationDetents([.medium])
        .presentationBackground(.clear)
    }

    private func triggerRow(title: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label {
                    Text(title)
                        .foregroundColor(isActive ? .accentColor : .primary)
                } icon: {
                    Image(systemName: icon)
                        .foregroundColor(isActive ? .accentColor : .primary)
                }
                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(isActive ? .accentColor : .primary)
            }
            .padding(.vertical, 4)
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

    private func select(_ destination: MemoryTriggerPickerDestination) {
        selectedDestination = destination
    }
}
