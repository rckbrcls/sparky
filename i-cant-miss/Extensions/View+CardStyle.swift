import SwiftUI

extension View {
    func cardStyle(cornerRadius: CGFloat = 12) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color("ElementBackground"))
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color("ElementBorder"), lineWidth: 2)
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
