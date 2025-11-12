import PhotosUI
import SwiftUI

struct MemoryEditorPhotoToolbarControls: View {
    @Binding var selectedItems: [PhotosPickerItem]
    var onCameraTap: () -> Void
    var isHighlighted: Bool
    var isEnabled: Bool

    init(
        selectedItems: Binding<[PhotosPickerItem]>,
        isHighlighted: Bool = false,
        isEnabled: Bool = true,
        onCameraTap: @escaping () -> Void
    ) {
        self._selectedItems = selectedItems
        self.isHighlighted = isHighlighted
        self.isEnabled = isEnabled
        self.onCameraTap = onCameraTap
    }

    var body: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $selectedItems, matching: .images) {
                Label("Add from library", systemImage: "photo.stack")
            }
            .labelStyle(.iconOnly)
            .foregroundStyle(foregroundStyle)
            .disabled(!isEnabled)

            Button {
                onCameraTap()
            } label: {
                Label("Capture photo", systemImage: "camera")
            }
            .labelStyle(.iconOnly)
            .foregroundStyle(foregroundStyle)
            .disabled(!isEnabled)
        }
        .accessibilityElement(children: .contain)
    }

    private var foregroundStyle: Color {
        guard isEnabled else { return .secondary }
        return isHighlighted ? Color.accentColor : Color.primary
    }
}
