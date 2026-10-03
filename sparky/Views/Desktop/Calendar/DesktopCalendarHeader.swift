#if os(macOS)

import SwiftUI

struct DesktopCalendarHeader: View {
    let title: DesktopCalendarTitle
    let onPrevious: () -> Void
    let onToday: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title.leading)
                    .font(.system(size: 40, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if !title.trailing.isEmpty {
                    Text(title.trailing)
                        .font(.system(size: 40, weight: .light))
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 32)

            HStack(spacing: 8) {
                navigationButton(
                    title: "Previous",
                    systemImage: "chevron.left",
                    action: onPrevious
                )

                Button(action: onToday) {
                    Text("Today")
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 18)
                        .frame(height: 34)
                        .background(Color.Theme.elementBackground, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(Color.Theme.elementBorder, lineWidth: 1)
                        }
                        .buttonHitArea(Capsule())
                }
                .buttonStyle(.plain)

                navigationButton(
                    title: "Next",
                    systemImage: "chevron.right",
                    action: onNext
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }

    private func navigationButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 34, height: 34)
                .buttonHitArea(Circle())
                .background(Color.Theme.elementBackground, in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color.Theme.elementBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }
}

#endif
