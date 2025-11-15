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
            .foregroundStyle(isSelected ? Color.accent : .primary)
            .glassEffect(
                isSelected ? .regular.tint(Color.accent.opacity(0.2)).interactive() : .regular.interactive()
            )
        }
        .buttonStyle(.plain)
    }
}
