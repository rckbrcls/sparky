import SwiftUI

struct MemoryLocationTriggerEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel

    var body: some View {
        LocationPickerView { name, latitude, longitude, radius, event in
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


