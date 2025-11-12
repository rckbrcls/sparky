import SwiftUI

struct MemoryEditorPhotoToolbarControls: View {
    var onLibraryTap: () -> Void
    var onCameraTap: () -> Void
    var isHighlighted: Bool
    var isEnabled: Bool

    init(
        isHighlighted: Bool = false,
        isEnabled: Bool = true,
        onLibraryTap: @escaping () -> Void,
        onCameraTap: @escaping () -> Void
    ) {
        self.onLibraryTap = onLibraryTap
        self.onCameraTap = onCameraTap
        self.isHighlighted = isHighlighted
        self.isEnabled = isEnabled
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onLibraryTap()
            } label: {
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
