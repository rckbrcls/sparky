#if os(macOS)

import SwiftUI

struct DesktopCalendarHeader: View {
    let anchorDate: Date
    let onPrevious: () -> Void
    let onToday: () -> Void
    let onNext: () -> Void

    private var month: String {
        anchorDate.formatted(.dateTime.month(.wide))
    }

    private var year: String {
        anchorDate.formatted(.dateTime.year())
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(month)
                    .font(.system(size: 40, weight: .bold))

                Text(year)
                    .font(.system(size: 40, weight: .light))
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 32)

            HStack(spacing: 8) {
                navigationButton(
                    title: "Previous",
                    systemImage: "chevron.left",
                    action: onPrevious
                )

                Button("Today", action: onToday)
                    .buttonStyle(.plain)
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 18)
                    .frame(height: 34)
                    .background(Color.Theme.elementBackground, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.Theme.elementBorder, lineWidth: 1)
                    }

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
