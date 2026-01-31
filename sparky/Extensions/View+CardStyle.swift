import SwiftUI

extension View {
    func cardStyle(cornerRadius: CGFloat = 24) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.Theme.tertiaryBackground)
                    .stroke(Color.Theme.border, lineWidth: 1)
                    .shadow(color: .black.opacity(0.1), radius: 24, x: 3, y: 3)
            )
            .contentShape(Rectangle())
    }

    func neutralButtonStyle(cornerRadius: CGFloat = 24, verticalPadding: CGFloat = 12) -> some View {
        self
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
            .cardStyle(cornerRadius: cornerRadius)
    }
}
