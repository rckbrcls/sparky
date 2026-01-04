import SwiftUI
import MapKit

extension LocationPickerView {
    struct ExpandedMapScreen<MapContent: View,
                             CenterIndicator: View>: View {
        @ObservedObject var searchModel: LocationSearchViewModel
        @Binding var event: LocationEvent
        let mapContent: () -> MapContent
        let centerIndicator: () -> CenterIndicator
        let onSuggestionSelected: (MKLocalSearchCompletion) -> Void
        let onConfirm: () -> Void
        let onDismiss: () -> Void

        // This State property controls the presentation detent.
        // We start with a smaller detent so the map is visible.
        @State private var presentationDetent: PresentationDetent = .height(120)
        @FocusState private var isSearchFocused: Bool

        var body: some View {
            NavigationStack {
                ZStack {
                    mapContent()
                        .ignoresSafeArea()

                    centerIndicator()
                }
                .sheet(isPresented: .constant(true)) {
                    VStack(spacing: 20) {
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search for a place...", text: $searchModel.query)
                                .focused($isSearchFocused)
                                .submitLabel(.search)
                            if !searchModel.query.isEmpty {
                                Button(action: {
                                    searchModel.query = ""
                                    searchModel.suggestions = []
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(12)
                        .glassEffect()
                        .padding(.horizontal)

                        // Content switching based on search state
                        if isSearchFocused || !searchModel.query.isEmpty {
                            // Suggestions List
                            List(searchModel.suggestions, id: \.self) { suggestion in
                                Button(action: {
                                    onSuggestionSelected(suggestion)
                                }) {
                                    VStack(alignment: .leading) {
                                        Text(suggestion.title)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        if !suggestion.subtitle.isEmpty {
                                            Text(suggestion.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                        }

                        Spacer()
                    }
                    .padding(.top)
                    .presentationDetents([.height(120), .large], selection: $presentationDetent)
                    .presentationCornerRadius(24)
                    .presentationBackgroundInteraction(.enabled(upThrough: .height(120)))
                    .interactiveDismissDisabled()
                    .onChange(of: isSearchFocused) { _, focused in
                        if focused {
                            presentationDetent = .large
                        } else if searchModel.query.isEmpty {
                            presentationDetent = .height(120)
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Menu {
                            Picker("Trigger", selection: $event) {
                                Label("Arriving", systemImage: "arrow.down.right.circle.fill")
                                    .tag(LocationEvent.onEntry)
                                Label("Leaving", systemImage: "arrow.up.right.circle.fill")
                                    .tag(LocationEvent.onExit)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(event == .onEntry ? "Arriving" : "Leaving")
                                    .fontWeight(.semibold)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                            .padding(.horizontal)
                            .padding(.vertical, 14)
                            .glassEffect()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Set Area", action: onConfirm)
                            .fontWeight(.semibold)
                            .buttonStyle(.glassProminent)
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.secondary)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                }
            }
        }
    }
}
