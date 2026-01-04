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
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
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
                    .onChange(of: isSearchFocused) { focused in
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
                            HStack(spacing: 4) {
                                Text(event == .onEntry ? "Arriving" : "Leaving")
                                    .fontWeight(.semibold)
                                Image(systemName: "chevron.down.circle.fill")
                                    .resizable()
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Set Area", action: onConfirm)
                            .fontWeight(.semibold)
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
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
