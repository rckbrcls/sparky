import SwiftUI

struct TriggerPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    @State private var showDateAndTimeSheet = false
    @State private var showLocationSheet = false
    @State private var showPersonSheet = false
    @State private var showSequentialSheet = false
    @State private var showFocusSheet = false

    var body: some View {
        NavigationStack {
            List {
                triggerRow(
                    title: "Date & Time",
                    icon: "clock.badge",
                    isActive: isDateAndTimeActive
                ) {
                    showDateAndTimeSheet = true
                }

                triggerRow(
                    title: "Location",
                    icon: "mappin.circle.fill",
                    isActive: isLocationActive
                ) {
                    showLocationSheet = true
                }

                triggerRow(
                    title: "Person",
                    icon: "person.crop.circle.badge.plus",
                    isActive: isPersonActive
                ) {
                    showPersonSheet = true
                }

                triggerRow(
                    title: "Sequence",
                    icon: "arrow.right",
                    isActive: isSequentialActive
                ) {
                    showSequentialSheet = true
                }

                triggerRow(
                    title: "Focus",
                    icon: "moon.fill",
                    isActive: isFocusActive
                ) {
                    showFocusSheet = true
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
            .sheet(isPresented: $showDateAndTimeSheet) {
                NavigationStack {
                    ScheduledTriggerEditorScreen(viewModel: viewModel)
                }
            }
            .sheet(isPresented: $showLocationSheet) {
                NavigationStack {
                    LocationTriggerEditorScreen(viewModel: viewModel)
                }
            }
            .sheet(isPresented: $showPersonSheet) {
                NavigationStack {
                    PersonTriggerEditorScreen(viewModel: viewModel)
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showSequentialSheet) {
                NavigationStack {
                    SequentialTriggerEditorScreen(
                        viewModel: viewModel,
                        excludedMemoryID: viewModel.editingMemoryID
                    )
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showFocusSheet) {
                NavigationStack {
                    FocusTriggerEditorScreen(viewModel: viewModel)
                }
                .presentationDetents([.medium])
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
}
