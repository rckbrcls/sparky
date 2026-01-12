import SwiftUI

extension View {
    func cardStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 16/255, green: 16/255, blue: 16/255))
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 20/255, green: 20/255, blue: 20/255), lineWidth: 2)
            )
            .contentShape(Rectangle())
    }
}
