import SwiftUI

struct LocationTriggerEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    private let showsCloseButton: Bool
    private var existingTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .location })
    }

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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if existingTrigger != nil {
                    Button(role: .destructive, action: removeLocationTrigger) {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Remove location trigger")
                }
            }
        }
    }

    private func removeLocationTrigger() {
        guard let trigger = existingTrigger else { return }
        viewModel.removeTrigger(id: trigger.id)
        dismiss()
    }
}
