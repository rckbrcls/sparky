import SwiftUI

struct FilterBadgesBar: View {
    @Binding var selectedTriggerTypes: Set<MemoryTriggerType>
    @Binding var selectedContentTypes: Set<MemoryContentFilterType>
    @Binding var showInbox: Bool
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
                    Label("Triggers", systemImage: "bolt.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                    if hasActiveTriggerFilter {
                        Text("\(activeTriggerCount)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }

                FilterBadgeButton(
                    accessibilityLabel: "Filter content",
                    action: {
                        showContentSheet = true
                    }
                ) {
                    Label("Content", systemImage: "doc.text")
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                    if hasActiveContentFilter {
                        Text("\(activeContentCount)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }

                FilterBadgeButton(
                    isToggle: true,
                    isActive: showInbox,
                    accessibilityLabel: showInbox ? "Hide inbox" : "Show inbox",
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showInbox.toggle()
                        }
                    }
                ) {
                    Label("Show Inbox", systemImage: "tray.fill")
                        .font(.caption.bold())
                        .foregroundStyle(showInbox ? .white : .primary)
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
                    Label("Pinned", systemImage: "pin.fill")
                        .font(.caption.bold())
                        .foregroundStyle(showPinned ? .white : .primary)
                }
            }
            .padding(.horizontal, 4)
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
