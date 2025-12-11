import SwiftUI

struct FilterBadgesBar: View {
    @Binding var selectedTriggerTypes: Set<MemoryTriggerType>
    @Binding var selectedContentTypes: Set<MemoryContentFilterType>
    @Binding var showPinned: Bool
    @Binding var showTriggerSheet: Bool
    @Binding var showContentSheet: Bool

    private var activeTriggerCount: Int {
        if selectedTriggerTypes.isEmpty {
            return MemoryTriggerType.allCases.count
        }
        return selectedTriggerTypes.count
    }

    private var activeContentCount: Int {
        if selectedContentTypes.isEmpty {
            return MemoryContentFilterType.allCases.count
        }
        return selectedContentTypes.count
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center, spacing: 10) {
                FilterBadgeButton(
                    accessibilityLabel: "Filter triggers",
                    action: {
                        showTriggerSheet = true
                    }
                ) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                        Text("Triggers")
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                }

                FilterBadgeButton(
                    accessibilityLabel: "Filter content",
                    action: {
                        showContentSheet = true
                    }
                ) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                        Text("Content")
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                }

                FilterBadgeButton(
                    isToggle: true,
                    isActive: showPinned,
                    accessibilityLabel: showPinned ? "Hide pinned" : "Show pinned",
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showPinned.toggle()
                        }
                    }
                ) {
                    HStack(spacing: 4) {
                        Image(systemName: "pin.fill")
                        Text("Pinned")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(showPinned ? .white : .primary)
                }
            }
            .padding(.leading, 20)
            .padding(.vertical, 1) // Prevent border clipping
        }
        .scrollIndicators(.hidden)
    }

    private var hasActiveTriggerFilter: Bool {
        !selectedTriggerTypes.isEmpty && selectedTriggerTypes.count < MemoryTriggerType.allCases.count
    }

    private var hasActiveContentFilter: Bool {
        !selectedContentTypes.isEmpty && selectedContentTypes.count < MemoryContentFilterType.allCases.count
    }
}
