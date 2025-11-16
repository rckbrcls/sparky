import SwiftUI

struct MemoryEditorTriggerButtonsBar: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    var onAddTrigger: (() -> Void)? = nil
    @Binding var showDateAndTimeSheet: Bool
    @Binding var showLocationPicker: Bool
    @Binding var showPersonSheet: Bool
    @Binding var showSequentialSheet: Bool
    let memoryLookup: [UUID: MemoryModel]

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let onAddTrigger {
                Button {
                    onAddTrigger()
                } label: {
                    HStack {
                        Label("Trigger", systemImage: "bolt.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.glassProminent)
                .accessibilityLabel("Add trigger")
            }
            if hasScheduledTrigger {
                MemoryDateAndTimeTriggerInlineForm(
                    viewModel: viewModel,
                    showSheet: $showDateAndTimeSheet
                )
            }
            if hasLocationTrigger {
                MemoryLocationTriggerInlineForm(
                    viewModel: viewModel,
                    showLocationPicker: $showLocationPicker
                )
            }
            if hasPersonTrigger {
                MemoryPersonTriggerInlineForm(
                    viewModel: viewModel,
                    showSheet: $showPersonSheet
                )
            }
            if hasSequentialTrigger {
                MemorySequentialTriggerInlineForm(
                    viewModel: viewModel,
                    showSheet: $showSequentialSheet,
                    memoryLookup: memoryLookup
                )
            }
        }
    }

    private var hasScheduledTrigger: Bool {
        viewModel.triggers.contains(where: { $0.type == .scheduled })
    }

    private var hasLocationTrigger: Bool {
        viewModel.triggers.contains(where: { $0.type == .location })
    }

    private var hasPersonTrigger: Bool {
        viewModel.triggers.contains(where: { $0.type == .person })
    }

    private var hasSequentialTrigger: Bool {
        guard let configuration = viewModel.sequentialTrigger?.sequential else { return false }
        return configuration.previousMemoryID != nil || configuration.nextMemoryID != nil
    }
}
