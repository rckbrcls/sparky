#if os(macOS)

import SwiftUI

struct DesktopPopoverActionBar: View {
    let confirmationAccessibilityLabel: String
    var confirmationSystemImage = "checkmark"
    var isConfirmationDisabled = false
    var destructiveAccessibilityLabel: String?
    var secondaryAccessibilityLabel: String?
    var secondarySystemImage: String?
    var cancellationAccessibilityLabel = "Cancel"
    let onCancel: () -> Void
    let onConfirm: () -> Void
    var onDestructive: (() -> Void)?
    var onSecondary: (() -> Void)?

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button(role: .cancel, action: onCancel) {
                    actionLabel(systemImage: "xmark")
                }
                .buttonStyle(.plain)
                .neutralToolbarItemStyle()
                .glassEffect(.regular.interactive(), in: .circle)
                .contentShape(Circle())
                .accessibilityLabel(cancellationAccessibilityLabel)
                .help(cancellationAccessibilityLabel)

                if let destructiveAccessibilityLabel, let onDestructive {
                    Button(role: .destructive, action: onDestructive) {
                        actionLabel(systemImage: "trash")
                    }
                    .buttonStyle(.plain)
                    .neutralToolbarItemStyle()
                    .glassEffect(.regular.interactive(), in: .circle)
                    .contentShape(Circle())
                    .accessibilityLabel(destructiveAccessibilityLabel)
                    .help(destructiveAccessibilityLabel)
                }

                Spacer()

                if let secondaryAccessibilityLabel,
                   let secondarySystemImage,
                   let onSecondary {
                    Button(action: onSecondary) {
                        actionLabel(systemImage: secondarySystemImage)
                    }
                    .buttonStyle(.plain)
                    .neutralToolbarItemStyle()
                    .glassEffect(.regular.interactive(), in: .circle)
                    .contentShape(Circle())
                    .accessibilityLabel(secondaryAccessibilityLabel)
                    .help(secondaryAccessibilityLabel)
                }

                Button(role: .confirm, action: onConfirm) {
                    actionLabel(systemImage: confirmationSystemImage)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.Theme.accentForeground)
                .glassEffect(
                    .regular.interactive().tint(Color.accentColor),
                    in: .circle
                )
                .contentShape(Circle())
                .disabled(isConfirmationDisabled)
                .opacity(isConfirmationDisabled ? 0.45 : 1)
                .accessibilityLabel(confirmationAccessibilityLabel)
                .help(confirmationAccessibilityLabel)
            }
        }
    }

    private func actionLabel(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
    }
}

#endif
