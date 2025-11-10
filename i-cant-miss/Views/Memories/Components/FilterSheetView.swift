import SwiftUI

struct FilterSheetView: View {
    @Environment(\.dismiss) var dismiss

    @Binding var selectedMemoryTypes: Set<MemoryType>
    @Binding var selectedSections: Set<MemoryService.TimelineSection.Kind>
    @Binding var showInbox: Bool
    @Binding var detentSelection: PresentationDetent

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedMemoryTypes.removeAll()
                        }
                    } label: {
                        HStack {
                            Label("All Types", systemImage: "square.stack.3d.up.fill")
                                .foregroundStyle(Color.accent)
                            Spacer()
                            if selectedMemoryTypes.isEmpty || selectedMemoryTypes.count == MemoryType.allCases.count {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accent)
                                    .fontWeight(.semibold)
                            }
                        }
                    }

                    ForEach(MemoryType.allCases) { type in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                toggleMemoryType(type)
                            }
                        } label: {
                            HStack {
                                Label(type.label, systemImage: type.systemImage)
                                    .foregroundStyle(Color.accent)
                                Spacer()
                                if isMemoryTypeVisuallySelected(type) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accent)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Memory Type")
                }

                Section {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSections.removeAll()
                        }
                    } label: {
                        HStack {
                            Label("All Sections", systemImage: "calendar")
                                .foregroundStyle(Color.accent)
                            Spacer()
                            if selectedSections.isEmpty || selectedSections.count == MemoryService.TimelineSection.Kind.allCases.count {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accent)
                                    .fontWeight(.semibold)
                            }
                        }
                    }

                    ForEach(MemoryService.TimelineSection.Kind.allCases) { kind in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                toggleSection(kind)
                            }
                        } label: {
                            HStack {
                                Label(kind.title, systemImage: kind.systemImage)
                                    .foregroundStyle(Color.accent)
                                Spacer()
                                if isSectionVisuallySelected(kind) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accent)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
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
                                .foregroundStyle(Color.accent)
                            Spacer()
                            if showInbox {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accent)
                                    .fontWeight(.semibold)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
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
                            selectedMemoryTypes.removeAll()
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
                            selectedMemoryTypes.removeAll()
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

    private func isMemoryTypeVisuallySelected(_ type: MemoryType) -> Bool {
        if selectedMemoryTypes.isEmpty {
            return true
        }
        return selectedMemoryTypes.contains(type)
    }

    private func toggleMemoryType(_ type: MemoryType) {
        if selectedMemoryTypes.contains(type) {
            selectedMemoryTypes.remove(type)
        } else {
            selectedMemoryTypes.insert(type)
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
