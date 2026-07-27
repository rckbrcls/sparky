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
        LocationPickerView(
            showsCloseButton: showsCloseButton,
            onRemove: existingConfig == nil ? nil : {
                viewModel.removeLocationConfig()
            }
        ) { name, latitude, longitude, radius, event in
            viewModel.setLocationConfig(
                name: name,
                latitude: latitude,
                longitude: longitude,
                radius: radius,
                event: event
            )
        }
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .primaryAction) {
                if existingConfig != nil {
                    Button(role: .destructive, action: removeLocationConfig) {
                        Image(systemName: "trash")
                    }
                    .neutralToolbarItemStyle()
                    .accessibilityLabel("Remove location trigger")
                }
            }
            #endif
        }
    }

    private func removeLocationConfig() {
        viewModel.removeLocationConfig()
        dismiss()
    }
}
