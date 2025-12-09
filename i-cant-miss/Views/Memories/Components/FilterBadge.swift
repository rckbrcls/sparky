import SwiftUI

struct FilterBadge: View {
    let label: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption)
                Text(label)
                    .font(.caption.weight(.medium))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accent : Color.clear)
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : Color.primary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
