import SwiftUI

extension LocationPickerView {
    struct MapSection<MapPreview: View>: View {
        let onExpand: () -> Void
        let mapPreview: () -> MapPreview

        var body: some View {
            Button(action: onExpand) {
                ZStack {
                    mapPreview()
                    Color.black.opacity(0.001)
                }
                .aspectRatio(16/9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .shadow(color: Color.black.opacity(0.1), radius: 16, y: 8)
        }
    }
}
