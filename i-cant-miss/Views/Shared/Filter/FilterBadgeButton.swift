import SwiftUI

struct FilterBadgeButton<Content: View>: View {
    let content: Content
    let isToggle: Bool
    let isActive: Bool
    let action: () -> Void
    let accessibilityLabel: String

    init(
        isToggle: Bool = false,
        isActive: Bool = false,
        accessibilityLabel: String,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isToggle = isToggle
        self.isActive = isActive
        self.accessibilityLabel = accessibilityLabel
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            HStack {
                content
            }
            .padding(.horizontal, 8)
            .frame(height: 40)
            .contentShape(Rectangle())
            .applyGlassEffect(isToggle: isToggle, isActive: isActive)
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

private extension View {
    @ViewBuilder
    func applyGlassEffect(isToggle: Bool, isActive: Bool) -> some View {
        if isToggle {
            self.glassEffect(isActive ? .regular.tint(.accent).interactive() : .regular.interactive())
        } else {
            self.glassEffect(.regular.interactive())
        }
    }
}
