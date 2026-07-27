import SwiftUI

struct WeeklyRhythmCard: View {
    let rhythm: MeMetrics.RhythmSummary
    let completionRate: MeMetrics.CompletionRate
    let insight: MeMetrics.Insight

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your rhythm")
                .font(.title3)
                .bold()

            if rhythm.hasReliablePattern {
                rhythmRows
            } else {
                Text(learningMessage)
                    .font(.subheadline)
                    .foregroundStyle(Color.Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if completionRate.isAvailable {
                Divider()
                metricRow(
                    title: "Scheduled completion",
                    value: completionRateText
                )
            }

            if shouldShowInsight {
                Divider()
                insightSummary
            }
        }
        .padding(20)
        .cardStyle(cornerRadius: 20)
    }
}

private extension WeeklyRhythmCard {
    @ViewBuilder
    var rhythmRows: some View {
        if let period = rhythm.mostActivePeriod {
            metricRow(
                title: "Most active period",
                value: period.title
            )
        }

        if rhythm.mostActivePeriod != nil, rhythm.bestWeekday != nil {
            Divider()
        }

        if let weekday = rhythm.bestWeekday {
            metricRow(
                title: "Best completion day",
                value: MeMetrics.englishWeekdayName(for: weekday)
            )
        }
    }

    var insightSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(insight.title)
                .font(.subheadline)
                .bold()

            Text(insight.message)
                .font(.subheadline)
                .foregroundStyle(Color.Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    func metricRow(title: String, value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .foregroundStyle(Color.Theme.textSecondary)
                Spacer(minLength: 12)
                Text(value)
                    .bold()
                    .multilineTextAlignment(.trailing)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundStyle(Color.Theme.textSecondary)
                Text(value)
                    .bold()
            }
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }

    var learningMessage: String {
        let remaining = max(
            MeMetrics.minimumRhythmSampleCount - rhythm.sampleCount,
            0
        )
        guard remaining > 0 else {
            return "Your recent activity is balanced. Keep going and a clearer pattern will emerge."
        }
        let memoryLabel = remaining == 1 ? "memory" : "memories"
        if rhythm.sampleCount == 0 {
            return "Complete \(remaining) \(memoryLabel) to reveal your rhythm."
        }
        return "Complete \(remaining) more \(memoryLabel) to reveal your rhythm."
    }

    var shouldShowInsight: Bool {
        insight != .buildingPattern
    }

    var completionRateText: String {
        "\(Int((completionRate.value * 100).rounded()))%"
    }
}
