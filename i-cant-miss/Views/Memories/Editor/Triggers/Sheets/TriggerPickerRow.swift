import SwiftUI

struct TriggerPickerRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(isActive ? Color.accentColor : Color.accentColor.opacity(0.85))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundColor(isActive ? .accentColor : .primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(isActive ? Color.accentColor.opacity(0.75) : .secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if isActive {
                    activeBadge
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(isActive ? Color.accentColor : Color(.tertiaryLabel))
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private var activeBadge: some View {
        Text("Active")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
        )
    }
}
