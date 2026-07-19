import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private struct AppLargeTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if canImport(UIKit) && os(iOS)
        content
            .font(.custom(
                "Baskerville",
                size: UIFont.preferredFont(forTextStyle: .largeTitle).pointSize,
                relativeTo: .largeTitle
            ))
            .fontWeight(.bold)
        #else
        content
            .font(.custom("Baskerville", size: 28, relativeTo: .largeTitle))
            .fontWeight(.bold)
        #endif
    }
}

extension View {
    func appLargeTitleStyle() -> some View {
        modifier(AppLargeTitleModifier())
    }
}
