import SwiftUI

extension View {
    func cardStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("ElementBackground"))
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color("ElementBorder"), lineWidth: 2)
            )
            .contentShape(Rectangle())
    }
}
