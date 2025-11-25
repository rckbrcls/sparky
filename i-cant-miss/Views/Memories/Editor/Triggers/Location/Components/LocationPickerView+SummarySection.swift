import SwiftUI

extension LocationPickerView {
    struct SummarySection: View {
        let resolvedLocationName: String
        let coordinateSummary: String
        let defaultRadius: Double

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Location summary")
                    .font(.headline)

                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(resolvedLocationName)
                            .font(.body.weight(.semibold))
                        Text(coordinateSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(Color.accentColor)
                }

                Divider()

                Label("Geofence radius \(Int(defaultRadius)) m", systemImage: "dot.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
        }
    }
}
