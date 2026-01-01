import SwiftUI

struct FilterBadgesBar: View {
    @Binding var selectedTriggerTypes: Set<MemoryTriggerType>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center, spacing: 10) {

                // Individual trigger type toggles
                ForEach(MemoryTriggerType.allCases) { triggerType in
                    FilterBadgeButton(
                        isToggle: true,
                        isActive: isTriggerTypeActive(triggerType),
                        accessibilityLabel: triggerType.label,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                toggleTriggerType(triggerType)
                            }
                        }
                    ) {
                        HStack(spacing: 4) {
                            Image(systemName: triggerType.systemImage)
                            Text(triggerType.label)
                        }
                        .font(.caption2.bold())
                        .foregroundStyle(isTriggerTypeActive(triggerType) ? .white : .primary)
                    }
                }
            }
            .padding(.leading, 20)
            .padding(.vertical, 1) // Prevent border clipping
        }
        .scrollIndicators(.hidden)
    }

    private func isTriggerTypeActive(_ type: MemoryTriggerType) -> Bool {
        // When set is empty, all types are considered active (no filter)
        // When set has items, only those items are active
        selectedTriggerTypes.isEmpty || selectedTriggerTypes.contains(type)
    }

    private func toggleTriggerType(_ type: MemoryTriggerType) {
        if selectedTriggerTypes.isEmpty {
            // First toggle: select only this type (deselect all others)
            selectedTriggerTypes = [type]
        } else if selectedTriggerTypes.contains(type) {
            selectedTriggerTypes.remove(type)
            // If removing the last one, reset to empty (show all)
            // This is optional behavior - could also leave it empty to show none
        } else {
            selectedTriggerTypes.insert(type)
        }
    }
}
