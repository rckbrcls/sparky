import SwiftUI

extension LocationPickerView {
    struct ExpandedConfirmationPanel: View {
        let resolvedLocationName: String
        let coordinateSummary: String
        let isResolving: Bool
        let onUseLocation: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Capsule()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 40, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)

                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(resolvedLocationName)
                            .font(.body.weight(.semibold))
                        Text(coordinateSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }

                if isResolving {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(.circular)
                        Text("Resolving address…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Button(action: onUseLocation) {
                    Text("Use this location")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(Color.white)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.clear)
                    .liquidGlass(in: RoundedRectangle(cornerRadius: 22), addSubtleBorder: false)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 20, y: 12)
        }
    }
}
