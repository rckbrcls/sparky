import SwiftUI

extension LocationPickerView {
    struct MapSection<MapPreview: View>: View {
        let onExpand: () -> Void
        let mapPreview: () -> MapPreview

        var body: some View {
            Button(action: onExpand) {
                mapPreview()
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .shadow(color: Color.black.opacity(0.1), radius: 16, y: 8)
        }
    }
}
