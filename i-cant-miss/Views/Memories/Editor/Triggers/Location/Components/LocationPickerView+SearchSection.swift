import SwiftUI
import MapKit
import Combine

extension LocationPickerView {
    struct SearchSection: View {
        @ObservedObject var searchModel: LocationSearchViewModel
        let isSearching: Bool
        let onClearQuery: () -> Void
        let onSuggestionSelected: (MKLocalSearchCompletion) -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Search for a place")
                    .font(.headline)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Search for a place or pan the map", text: $searchModel.query)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)

                    if !searchModel.query.isEmpty {
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
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))

                if !searchModel.suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Suggestions")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 8)

                        ForEach(Array(searchModel.suggestions.enumerated()), id: \.offset) { index, suggestion in
                            Button {
                                onSuggestionSelected(suggestion)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(suggestion.title)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)

                            if index < searchModel.suggestions.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
        }
    }
}
