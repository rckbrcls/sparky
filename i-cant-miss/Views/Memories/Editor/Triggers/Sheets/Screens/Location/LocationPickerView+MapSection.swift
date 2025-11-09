import SwiftUI

extension LocationPickerView {
    struct MapSection<MapPreview: View, SelectionOverlay: View, Hint: View>: View {
        let defaultRadius: Double
        let onExpand: () -> Void
        let mapPreview: () -> MapPreview
        let selectionOverlay: () -> SelectionOverlay
        let hint: () -> Hint

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Adjust the pin")
                    .font(.headline)
                Text("Drag the map to position the pin. We'll monitor a \(Int(defaultRadius)) m radius automatically.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button(action: onExpand) {
                    ZStack(alignment: .top) {
                        mapPreview()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        selectionOverlay()
                        hint()
                    }
                    .frame(height: 280)
                    .contentShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
        }
    }
}
