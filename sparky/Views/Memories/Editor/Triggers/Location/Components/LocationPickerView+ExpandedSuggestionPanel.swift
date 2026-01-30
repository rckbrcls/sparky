import SwiftUI
import MapKit

extension LocationPickerView {
    struct ExpandedSuggestionPanel: View {
        let suggestions: [MKLocalSearchCompletion]
        let onSuggestionSelected: (MKLocalSearchCompletion) -> Void

        var body: some View {
            if suggestions.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Suggestions")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)

                    ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
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

                        if index < suggestions.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }
}
