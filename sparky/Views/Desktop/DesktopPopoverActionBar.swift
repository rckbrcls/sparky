#if os(macOS)

import SwiftUI

struct DesktopPopoverActionBar: View {
    let confirmationAccessibilityLabel: String
    var isConfirmationDisabled = false
    var destructiveAccessibilityLabel: String?
    let onCancel: () -> Void
    let onConfirm: () -> Void
    var onDestructive: (() -> Void)?

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button(role: .cancel, action: onCancel) {
                    Image(systemName: "xmark")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .neutralToolbarItemStyle()
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Cancel")

                if let destructiveAccessibilityLabel, let onDestructive {
                    Button(role: .destructive, action: onDestructive) {
                        Image(systemName: "trash")
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .neutralToolbarItemStyle()
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel(destructiveAccessibilityLabel)
                }

                Spacer()

                Button(role: .confirm, action: onConfirm) {
                    Image(systemName: "checkmark")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.Theme.accentForeground)
                .glassEffect(
                    .regular.interactive().tint(Color.accentColor),
                    in: .circle
                )
                .disabled(isConfirmationDisabled)
                .opacity(isConfirmationDisabled ? 0.45 : 1)
                .accessibilityLabel(confirmationAccessibilityLabel)
            }
        }
    }
}

#endif
