import SwiftUI

struct TriggerFilterSheetView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedTriggerTypes: Set<MemoryTriggerType>

    var body: some View {
        NavigationStack {
            List {
                ForEach(MemoryTriggerType.allCases) { triggerType in
                    Button {
                        toggleTriggerType(triggerType, isSelected: !isTriggerTypeSelected(triggerType))
                    } label: {
                        HStack {
                            Label(triggerType.label, systemImage: triggerType.systemImage)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: isTriggerTypeSelected(triggerType) ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(isTriggerTypeSelected(triggerType) ? .accent : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .background(.clear)
            .navigationTitle("Filter Triggers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Done", systemImage: "checkmark")
                    }
                }
            }
        }
    }

    private func isTriggerTypeSelected(_ triggerType: MemoryTriggerType) -> Bool {
        if selectedTriggerTypes.isEmpty {
            return true
        }
        return selectedTriggerTypes.contains(triggerType)
    }

    private func toggleTriggerType(_ triggerType: MemoryTriggerType, isSelected: Bool) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if isSelected {
                if selectedTriggerTypes.isEmpty {
                    // Se estava vazio (todos selecionados), agora seleciona apenas este
                    selectedTriggerTypes = [triggerType]
                } else {
                    selectedTriggerTypes.insert(triggerType)
                    // Se todos estão selecionados, limpa para representar "todos"
                    if selectedTriggerTypes.count == MemoryTriggerType.allCases.count {
                        selectedTriggerTypes.removeAll()
                    }
                }
            } else {
                if selectedTriggerTypes.isEmpty {
                    // Se estava vazio (todos selecionados), remove este e adiciona os outros
                    selectedTriggerTypes = Set(MemoryTriggerType.allCases.filter { $0 != triggerType })
                } else {
                    selectedTriggerTypes.remove(triggerType)
                }
            }
        }
    }
}
