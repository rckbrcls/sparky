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
            .padding(.horizontal)
            .frame(height: 40)
            .contentShape(Rectangle())
            .applySolidStyle(isToggle: isToggle, isActive: isActive)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private extension View {
    @ViewBuilder
    func applySolidStyle(isToggle: Bool, isActive: Bool) -> some View {
        let isSelected = isToggle && isActive
        self
            .background(
                Capsule()
                    .fill(isSelected ? Color(uiColor: .systemGray6) : Color.clear)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )
    }
}
