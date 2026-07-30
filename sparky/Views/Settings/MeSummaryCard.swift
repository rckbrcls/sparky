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
        let mood = MeCharacterMood.streak(for: streakDays)

        return metricPanel(
            title: "DAY STREAK",
            value: streakDays,
            target: streakTarget,
            unit: streakTarget == 1 ? "day" : "days",
            imageName: mood.streakImageName,
            characterSize: 106,
            accessibilityValue: streakAccessibilityValue
        )
    }

    var completionPanel: some View {
        let mood = MeCharacterMood.completed(for: completionCount)

        return metricPanel(
            title: "COMPLETED",
            value: completionCount,
            target: completionTarget,
            unit: "completed",
            imageName: mood.completedImageName,
            characterSize: 88,
            accessibilityValue: completionAccessibilityValue
        )
    }

    func metricPanel(
        title: String,
        value: Int,
        target: Int,
        unit: String,
        imageName: String,
        characterSize: CGFloat,
        accessibilityValue: String
    ) -> some View {
        VStack(spacing: 14) {
            characterValueStack(
                value: value,
                imageName: imageName,
                characterSize: characterSize
            )

            Text(title)
                .font(.caption.weight(.semibold))
                .tracking(dynamicTypeSize.isAccessibilitySize ? 0 : 1.2)
                .foregroundStyle(Color.Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

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

    func characterValueStack(
        value: Int,
        imageName: String,
        characterSize: CGFloat
    ) -> some View {
        ZStack {
            characterImage(
                named: imageName,
                size: characterSize
            )
                .offset(y: -24 - ((characterSize - 88) / 2))

            valueLabel(value)
                .offset(x: 20, y: 8)
        }
        .frame(height: 138)
        .offset(y: 30)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.2),
            value: imageName
        )
    }

    func characterImage(
        named imageName: String,
        size: CGFloat
    ) -> some View {
        Image(imageName)
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
            .frame(width: size, height: size)
            .id(imageName)
            .transition(.opacity)
            .accessibilityHidden(true)
    }

    func valueLabel(_ value: Int) -> some View {
        Text("\(value)")
            .font(
                .custom(
                    "Baskerville",
                    size: 42,
                    relativeTo: .largeTitle
                )
            )
            .bold()
            .monospacedDigit()
            .foregroundStyle(Color.Theme.textPrimary)
            .contentTransition(.numericText())
            .lineLimit(1)
            .minimumScaleFactor(0.42)
            .frame(width: 104, height: 50)
            .shadow(
                color: .black.opacity(0.38),
                radius: 5,
                y: 3
            )
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

#Preview("Sad - Light") {
    MeSummaryCard(streakDays: 0, completionCount: 0)
        .padding()
        .background(Color.Theme.secondaryBackground)
        .preferredColorScheme(.light)
}

#Preview("Hopeful - Dark") {
    MeSummaryCard(streakDays: 6, completionCount: 24)
        .padding()
        .background(Color.Theme.secondaryBackground)
        .preferredColorScheme(.dark)
}

#Preview("Happy") {
    MeSummaryCard(streakDays: 7, completionCount: 25)
        .padding()
        .background(Color.Theme.secondaryBackground)
}

#Preview("Euphoric") {
    MeSummaryCard(streakDays: 30, completionCount: 100)
        .padding()
        .background(Color.Theme.secondaryBackground)
}

#Preview("Long Values") {
    MeSummaryCard(streakDays: 1000, completionCount: 1000)
        .padding()
        .background(Color.Theme.secondaryBackground)
}

#Preview("Accessibility") {
    MeSummaryCard(streakDays: 30, completionCount: 100)
        .padding()
        .background(Color.Theme.secondaryBackground)
        .environment(\.dynamicTypeSize, .accessibility3)
}
