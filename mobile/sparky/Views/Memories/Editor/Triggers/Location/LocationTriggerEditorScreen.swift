import SwiftUI

struct LocationTriggerEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    private let showsCloseButton: Bool

    private var existingConfig: LocationConfigDraft? {
        viewModel.locationConfig
    }

    init(viewModel: MemoryEditorViewModel, showsCloseButton: Bool = true) {
        self.viewModel = viewModel
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        LocationPickerView(showsCloseButton: showsCloseButton) { name, latitude, longitude, radius, event in
            viewModel.setLocationConfig(
                name: name,
                latitude: latitude,
                longitude: longitude,
                radius: radius,
                event: event
            )
            dismiss()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if existingConfig != nil {
                    Button(role: .destructive, action: removeLocationConfig) {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Remove location trigger")
                }
            }
        }
    }

    private func removeLocationConfig() {
        viewModel.removeLocationConfig()
        dismiss()
    }
}
