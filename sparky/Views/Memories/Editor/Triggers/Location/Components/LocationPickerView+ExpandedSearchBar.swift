import SwiftUI

extension LocationPickerView {
    struct ExpandedSearchBar: View {
        @Binding var query: String
        let isSearching: Bool
        let onClearQuery: () -> Void

        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search for a place or pan the map", text: $query)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)

                if !query.isEmpty {
                    Button(action: onClearQuery) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }

                if isSearching {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
