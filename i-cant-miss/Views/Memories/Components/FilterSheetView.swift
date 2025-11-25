import SwiftUI

struct FilterSheetView: View {
    @Environment(\.dismiss) var dismiss

    @Binding var selectedContentTypes: Set<MemoryContentFilterType>
    @Binding var selectedTriggerTypes: Set<MemoryTriggerType>
    @Binding var showInbox: Bool
    @Binding var detentSelection: PresentationDetent

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    contentsSection
                    triggersSection
                    inboxSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(detentSelection == .medium)
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedContentTypes.removeAll()
                            selectedTriggerTypes.removeAll()
                            showInbox = true
                        }
                        dismiss()
                    } label: {
                        Label("Close", systemImage: "xmark")
                    }
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedContentTypes.removeAll()
                            selectedTriggerTypes.removeAll()
                            showInbox = true
                        }
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        dismiss()
                    } label: {
                        Label("Done", systemImage: "checkmark")
                    }
                }
            }
        }
    }

    private var contentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contents")
                .font(.headline)
                .foregroundStyle(.primary)

            FlowLayoutView(spacing: 8) {
                ForEach(MemoryContentFilterType.allCases) { contentType in
                    FilterBadge(
                        label: contentType.label,
                        systemImage: contentType.systemImage,
                        isSelected: isContentTypeVisuallySelected(contentType)
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            toggleContentType(contentType)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var triggersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Triggers")
                .font(.headline)
                .foregroundStyle(.primary)

            FlowLayoutView(spacing: 8) {
                ForEach(MemoryTriggerType.allCases) { triggerType in
                    FilterBadge(
                        label: triggerType.label,
                        systemImage: triggerType.systemImage,
                        isSelected: isTriggerTypeVisuallySelected(triggerType)
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            toggleTriggerType(triggerType)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var inboxSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inbox")
                .font(.headline)
                .foregroundStyle(.primary)

            FlowLayoutView(spacing: 8) {
                FilterBadge(
                    label: "Show Inbox",
                    systemImage: "tray.fill",
                    isSelected: showInbox
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showInbox.toggle()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func isContentTypeVisuallySelected(_ contentType: MemoryContentFilterType) -> Bool {
        if selectedContentTypes.isEmpty {
            return true
        }
        return selectedContentTypes.contains(contentType)
    }

    private func toggleContentType(_ contentType: MemoryContentFilterType) {
        if selectedContentTypes.contains(contentType) {
            selectedContentTypes.remove(contentType)
        } else {
            selectedContentTypes.insert(contentType)
        }
    }

    private func isTriggerTypeVisuallySelected(_ triggerType: MemoryTriggerType) -> Bool {
        if selectedTriggerTypes.isEmpty {
            return true
        }
        return selectedTriggerTypes.contains(triggerType)
    }

    private func toggleTriggerType(_ triggerType: MemoryTriggerType) {
        if selectedTriggerTypes.contains(triggerType) {
            selectedTriggerTypes.remove(triggerType)
        } else {
            selectedTriggerTypes.insert(triggerType)
        }
    }

}
