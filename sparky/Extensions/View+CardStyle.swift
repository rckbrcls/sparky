import SwiftUI

extension View {
    func cardStyle(cornerRadius: CGFloat = 24) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.Theme.tertiaryBackground)
                    .stroke(Color.Theme.border, lineWidth: 1)
                    .shadow(color: .black.opacity(0.06), radius: 24, x: 3, y: 3)
            )
            .contentShape(Rectangle())
    }

    @ViewBuilder
    func memoryEditorSectionStyle(
        usesLiquidGlass: Bool,
        cornerRadius: CGFloat = 24
    ) -> some View {
        #if os(macOS)
        if usesLiquidGlass {
            self
                .glassEffect(
                    .regular.interactive(),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .contentShape(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        } else {
            cardStyle(cornerRadius: cornerRadius)
        }
        #else
        cardStyle(cornerRadius: cornerRadius)
        #endif
    }

    func neutralButtonStyle(cornerRadius: CGFloat = 24, verticalPadding: CGFloat = 12) -> some View {
        self
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
            .cardStyle(cornerRadius: cornerRadius)
    }
}
