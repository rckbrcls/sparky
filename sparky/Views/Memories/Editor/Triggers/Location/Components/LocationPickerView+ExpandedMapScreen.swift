import SwiftUI
import MapKit

struct ExpandedMapScreen<MapContent: View>: View {
    @ObservedObject var searchModel: LocationSearchViewModel
    @Binding var event: LocationEvent
    let mapContent: () -> MapContent
    let onSuggestionSelected: (MKLocalSearchCompletion) -> Void
    let onConfirm: () -> Void
    let onDismiss: () -> Void
    
    // This State property controls the presentation detent.
    // We start with a smaller detent so the map is visible.
    @State private var presentationDetent: PresentationDetent = .height(120)
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationStack {
            mapContent()
                .ignoresSafeArea()
                .sheet(isPresented: .constant(true))
            {
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
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(searchModel.suggestions, id: \.self) { suggestion in
                                    Button(action: {
                                        onSuggestionSelected(suggestion)
                                        PlatformOpen.resignFirstResponder()
                                        presentationDetent = .height(120)
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
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .cardStyle()
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top)
                .presentationDetents([.height(120), .large], selection: $presentationDetent)
                .presentationBackgroundInteraction(.enabled(upThrough: .height(120)))
                .interactiveDismissDisabled()
                .presentationBackground(.clear)
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
                            Label(LocationEvent.onEntry.displayName, systemImage: "arrow.down.right.circle.fill")
                                .tag(LocationEvent.onEntry)
                            Label(LocationEvent.onExit.displayName, systemImage: "arrow.up.right.circle.fill")
                                .tag(LocationEvent.onExit)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(event.displayName)
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
                ToolbarItem(placement: .navigation) {
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
