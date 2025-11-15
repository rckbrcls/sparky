import SwiftUI

struct FilterSheetView: View {
    @Environment(\.dismiss) var dismiss

    @Binding var selectedContentTypes: Set<MemoryContentFilterType>
    @Binding var selectedTriggerTypes: Set<MemoryTriggerType>
    @Binding var selectedSections: Set<MemoryService.TimelineSection.Kind>
    @Binding var showInbox: Bool
    @Binding var detentSelection: PresentationDetent

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    contentsSection
                    triggersSection
                    timelineSectionsSection
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
                            selectedSections.removeAll()
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
                            selectedSections.removeAll()
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

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedContentTypes.removeAll()
                }
            } label: {
                HStack {
                    Label("All Contents", systemImage: "square.stack.3d.up.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    if selectedContentTypes.isEmpty || selectedContentTypes.count == MemoryContentFilterType.allCases.count {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accent)
                            .fontWeight(.semibold)
                    }
                }
            }
            .tint(.primary)

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
        }
    }

    private var triggersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Triggers")
                .font(.headline)
                .foregroundStyle(.primary)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTriggerTypes.removeAll()
                }
            } label: {
                HStack {
                    Label("All Triggers", systemImage: "alarm.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    if selectedTriggerTypes.isEmpty || selectedTriggerTypes.count == MemoryTriggerType.allCases.count {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accent)
                            .fontWeight(.semibold)
                    }
                }
            }
            .tint(.primary)

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
        }
    }

    private var timelineSectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline Section")
                .font(.headline)
                .foregroundStyle(.primary)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedSections.removeAll()
                }
            } label: {
                HStack {
                    Label("All Sections", systemImage: "calendar")
                        .foregroundStyle(.primary)
                    Spacer()
                    if selectedSections.isEmpty || selectedSections.count == MemoryService.TimelineSection.Kind.allCases.count {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accent)
                            .fontWeight(.semibold)
                    }
                }
            }
            .tint(.primary)

            FlowLayoutView(spacing: 8) {
                ForEach(MemoryService.TimelineSection.Kind.allCases) { kind in
                    FilterBadge(
                        label: kind.title,
                        systemImage: kind.systemImage,
                        isSelected: isSectionVisuallySelected(kind)
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            toggleSection(kind)
                        }
                    }
                }
            }
        }
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
        }
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

    private func isSectionVisuallySelected(_ kind: MemoryService.TimelineSection.Kind) -> Bool {
        if selectedSections.isEmpty {
            return true
        }
        return selectedSections.contains(kind)
    }

    private func toggleSection(_ kind: MemoryService.TimelineSection.Kind) {
        if selectedSections.contains(kind) {
            selectedSections.remove(kind)
        } else {
            selectedSections.insert(kind)
        }
    }
}
