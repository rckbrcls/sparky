import SwiftUI

extension LocationPickerView {
    struct ExpandedMapScreen<MapContent: View,
                              SelectionOverlay: View,
                              CenterIndicator: View,
                              SearchBar: View,
                              SuggestionPanel: View,
                              ConfirmationPanel: View>: View {
        @ObservedObject var searchModel: LocationSearchViewModel
        let suggestionBottomPadding: CGFloat
        let mapContent: () -> MapContent
        let selectionOverlay: () -> SelectionOverlay
        let centerIndicator: () -> CenterIndicator
        let searchBar: () -> SearchBar
        let suggestionPanel: () -> SuggestionPanel
        let confirmationPanel: () -> ConfirmationPanel
        var searchFieldFocus: FocusState<Bool>.Binding
        let onDismiss: () -> Void

        @Environment(\.dismiss) private var dismiss

        var body: some View {
            NavigationStack {
                ZStack {
                    mapContent()
                        .ignoresSafeArea()
                    VStack(spacing: 0) {
                        selectionOverlay()
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        Spacer()
                    }
                    centerIndicator()
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: close) {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        Text("Adjust location")
                            .font(.headline)
                    }
                    ToolbarItemGroup(placement: .bottomBar) {
                        searchBar()
                            .focused(searchFieldFocus)
                    }
                }
                .overlay(alignment: .bottom) {
                    VStack(spacing: 16) {
                        suggestionPanel()
                        confirmationPanel()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, suggestionBottomPadding)
                    .zIndex(1)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    searchFieldFocus.wrappedValue = true
                }
            }
            .onDisappear {
                searchFieldFocus.wrappedValue = false
            }
        }

        private func close() {
            dismiss()
            onDismiss()
        }
    }
}
