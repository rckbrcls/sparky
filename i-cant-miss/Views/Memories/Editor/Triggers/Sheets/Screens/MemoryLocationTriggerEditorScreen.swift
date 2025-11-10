import SwiftUI

struct MemoryLocationTriggerEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    private let showsCloseButton: Bool

    init(viewModel: MemoryEditorViewModel, showsCloseButton: Bool = true) {
        self.viewModel = viewModel
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        LocationPickerView(showsCloseButton: showsCloseButton) { name, latitude, longitude, radius, event in
            viewModel.addLocationTrigger(
                name: name,
                latitude: latitude,
                longitude: longitude,
                radius: radius,
                event: event
            )
            dismiss()
        }
    }
}
