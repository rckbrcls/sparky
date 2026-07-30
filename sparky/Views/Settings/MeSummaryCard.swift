import SwiftUI

struct MeSummaryCard: View {
    let streakDays: Int
    let completionCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 0) {
                    streakPanel

                    Divider()
                        .padding(.horizontal, 20)

                    completionPanel
                }
            } else {
                HStack(spacing: 0) {
                    streakPanel

                    Divider()
                        .padding(.vertical, 20)

                    completionPanel
                }
            }
        }
        .cardStyle(cornerRadius: 20)
    }
}

private extension MeSummaryCard {
    var streakTarget: Int {
        MeProgressMilestone.streakTarget(for: streakDays)
    }

    var completionTarget: Int {
        MeProgressMilestone.completionTarget(for: completionCount)
    }

    var streakPanel: some View {
        metricPanel(
            title: "DAY STREAK",
            value: streakDays,
            target: streakTarget,
            unit: streakTarget == 1 ? "day" : "days",
            imageName: "MeStreakCharacter",
            handsImageName: "MeStreakHands",
            accessibilityValue: streakAccessibilityValue
        )
    }

    var completionPanel: some View {
        metricPanel(
            title: "COMPLETED",
            value: completionCount,
            target: completionTarget,
            unit: "completed",
            imageName: "MeCompletedCharacter",
            handsImageName: "MeCompletedHands",
            accessibilityValue: completionAccessibilityValue
        )
    }

    func metricPanel(
        title: String,
        value: Int,
        target: Int,
        unit: String,
        imageName: String,
        handsImageName: String,
        accessibilityValue: String
    ) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Image(imageName)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 108, height: 108)
                    .accessibilityHidden(true)

                Text("\(value)")
                    .font(
                        .custom(
                            "Baskerville",
                            size: 52,
                            relativeTo: .largeTitle
                        )
                    )
                    .bold()
                    .monospacedDigit()
                    .foregroundStyle(Color.Theme.textPrimary)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.42)
                    .frame(width: 72, height: 64)
                    .shadow(
                        color: Color.Theme.tertiaryBackground,
                        radius: 2
                    )
                    .offset(y: 18)

                Image(handsImageName)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 108, height: 108)
                    .accessibilityHidden(true)
            }
            .frame(height: 118)

            Text(title)
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(Color.Theme.textPrimary)

            progressBar(value: value, target: target)

            Text("\(value)/\(target) \(unit)")
                .font(.caption)
                .foregroundStyle(Color.Theme.textSecondary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: 260)
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
    }

    func progressBar(value: Int, target: Int) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.Theme.border.opacity(0.85))

                Capsule()
                    .fill(Color.accentColor)
                    .frame(
                        width: geometry.size.width
                            * MeProgressMilestone.progress(
                                value: value,
                                target: target
                            )
                    )
            }
        }
        .frame(height: 7)
        .animation(
            reduceMotion
                ? nil
                : .spring(response: 0.35, dampingFraction: 1),
            value: value
        )
    }

    var streakAccessibilityValue: String {
        let currentUnit = streakDays == 1 ? "day" : "days"
        let targetUnit = streakTarget == 1 ? "day" : "days"
        return "\(streakDays) \(currentUnit), next milestone \(streakTarget) \(targetUnit)"
    }

    var completionAccessibilityValue: String {
        let currentUnit = completionCount == 1
            ? "completion"
            : "completions"
        let targetUnit = completionTarget == 1
            ? "completion"
            : "completions"
        return "\(completionCount) \(currentUnit) all time, next milestone \(completionTarget) \(targetUnit)"
    }
}

#Preview("Populated") {
    MeSummaryCard(streakDays: 4, completionCount: 42)
        .padding()
        .background(Color.Theme.secondaryBackground)
}

#Preview("Zero") {
    MeSummaryCard(streakDays: 0, completionCount: 0)
        .padding()
        .background(Color.Theme.secondaryBackground)
}

#Preview("Value 4") {
    MeSummaryCard(streakDays: 4, completionCount: 4)
        .padding()
        .background(Color.Theme.secondaryBackground)
}

#Preview("Value 42") {
    MeSummaryCard(streakDays: 42, completionCount: 42)
        .padding()
        .background(Color.Theme.secondaryBackground)
}

#Preview("Value 128") {
    MeSummaryCard(streakDays: 128, completionCount: 128)
        .padding()
        .background(Color.Theme.secondaryBackground)
}

#Preview("Value 1000") {
    MeSummaryCard(streakDays: 1000, completionCount: 1000)
        .padding()
        .background(Color.Theme.secondaryBackground)
}
