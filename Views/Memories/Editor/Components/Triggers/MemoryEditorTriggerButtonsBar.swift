import SwiftUI

struct MemoryEditorTriggerButtonsBar: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showTriggerPicker: Bool
    @Binding var showDueDateSheet: Bool
    @Binding var showExactTimeSheet: Bool
    @Binding var showWeekdaySheet: Bool
    @Binding var showLocationPicker: Bool
    @Binding var showPersonSheet: Bool
    @Binding var showSequentialSheet: Bool
    let memoryLookup: [UUID: MemoryModel]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                MemoryTriggerAddBadge(isPresented: $showTriggerPicker)
                if hasDueDateTrigger {
                    MemoryDueDateTriggerInlineForm(
                        viewModel: viewModel,
                        showSheet: $showDueDateSheet
                    )
                }
                if hasExactTimeTrigger {
                    MemoryExactTimeTriggerInlineForm(
                        viewModel: viewModel,
                        showSheet: $showExactTimeSheet
                    )
                }
                MemoryWeekdayTriggerInlineForm(
                    viewModel: viewModel,
                    showSheet: $showWeekdaySheet
                )
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
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private var hasLocationTrigger: Bool {
        viewModel.triggers.contains(where: { $0.type == .location })
    }

    private var hasPersonTrigger: Bool {
        viewModel.triggers.contains(where: { $0.type == .person })
    }

    private var hasDueDateTrigger: Bool {
        viewModel.dueDateEnabled
    }

    private var hasExactTimeTrigger: Bool {
        viewModel.triggers.contains { trigger in
            trigger.type == .time && trigger.fireDate != nil
        }
    }

    private var hasSequentialTrigger: Bool {
        guard let configuration = viewModel.sequentialTrigger?.sequential else { return false }
        return configuration.previousMemoryID != nil || configuration.nextMemoryID != nil
    }
}
