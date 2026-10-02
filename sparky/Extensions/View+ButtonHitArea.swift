import SwiftUI

extension View {
    /// Apply inside a button label, after its sizing and padding modifiers.
    func buttonHitArea<S: Shape>(_ shape: S) -> some View {
        contentShape(.interaction, shape)
    }
}
