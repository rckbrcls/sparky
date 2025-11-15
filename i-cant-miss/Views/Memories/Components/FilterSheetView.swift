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
            List {
                Section {
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

                    ForEach(MemoryContentFilterType.allCases) { contentType in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                toggleContentType(contentType)
                            }
                        } label: {
                            HStack {
                                Label(contentType.label, systemImage: contentType.systemImage)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if isContentTypeVisuallySelected(contentType) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accent)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                } header: {
                    Text("Contents")
                }

                Section {
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

                    ForEach(MemoryTriggerType.allCases) { triggerType in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                toggleTriggerType(triggerType)
                            }
                        } label: {
                            HStack {
                                Label(triggerType.label, systemImage: triggerType.systemImage)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if isTriggerTypeVisuallySelected(triggerType) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accent)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                } header: {
                    Text("Triggers")
                }

                Section {
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

                    ForEach(MemoryService.TimelineSection.Kind.allCases) { kind in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                toggleSection(kind)
                            }
                        } label: {
                            HStack {
                                Label(kind.title, systemImage: kind.systemImage)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if isSectionVisuallySelected(kind) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accent)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                } header: {
                    Text("Timeline Section")
                }

                Section {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showInbox.toggle()
                        }
                    } label: {
                        HStack {
                            Label("Show Inbox", systemImage: "tray.fill")
                                .foregroundStyle(.primary)
                            Spacer()
                            if showInbox {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accent)
                                    .fontWeight(.semibold)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                    .tint(.primary)
                } header: {
                    Text("Inbox")
                }
            }
            .scrollContentBackground(.hidden)
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
