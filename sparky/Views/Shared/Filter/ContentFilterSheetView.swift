import SwiftUI

struct ContentFilterSheetView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedContentTypes: Set<MemoryContentFilterType>

    var body: some View {
        NavigationStack {
            List {
                ForEach(MemoryContentFilterType.allCases) { contentType in
                    Button {
                        toggleContentType(contentType, isSelected: !isContentTypeSelected(contentType))
                    } label: {
                        HStack {
                            Label(contentType.label, systemImage: contentType.systemImage)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: isContentTypeSelected(contentType) ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(isContentTypeSelected(contentType) ? Color.accentColor : Color.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .cardStyle()
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollIndicators(.hidden)
            .navigationTitle("Filter Content")
            .inlinePhoneNavigationTitle()
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

    private func isContentTypeSelected(_ contentType: MemoryContentFilterType) -> Bool {
        if selectedContentTypes.isEmpty {
            return true
        }
        return selectedContentTypes.contains(contentType)
    }

    private func toggleContentType(_ contentType: MemoryContentFilterType, isSelected: Bool) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if isSelected {
                if selectedContentTypes.isEmpty {
                    // Se estava vazio (todos selecionados), agora seleciona apenas este
                    selectedContentTypes = [contentType]
                } else {
                    selectedContentTypes.insert(contentType)
                    // Se todos estão selecionados, limpa para representar "todos"
                    if selectedContentTypes.count == MemoryContentFilterType.allCases.count {
                        selectedContentTypes.removeAll()
                    }
                }
            } else {
                if selectedContentTypes.isEmpty {
                    // Se estava vazio (todos selecionados), remove este e adiciona os outros
                    selectedContentTypes = Set(MemoryContentFilterType.allCases.filter { $0 != contentType })
                } else {
                    selectedContentTypes.remove(contentType)
                }
            }
        }
    }
}
// End of file
