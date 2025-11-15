import SwiftUI

struct MemoryEditorTriggerButtonsBar: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showDateAndTimeSheet: Bool
    @Binding var showLocationPicker: Bool
    @Binding var showPersonSheet: Bool
    @Binding var showSequentialSheet: Bool
    let memoryLookup: [UUID: MemoryModel]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
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
            .padding(.vertical, 8)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
