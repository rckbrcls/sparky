import SwiftUI
import UIKit

private struct AppLargeTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.custom(
                "PlayfairDisplay-Regular",
                size: UIFont.preferredFont(forTextStyle: .largeTitle).pointSize,
                relativeTo: .largeTitle
            ))
            .fontWeight(.bold)
    }
}

extension View {
    func appLargeTitleStyle() -> some View {
        modifier(AppLargeTitleModifier())
    }
}
