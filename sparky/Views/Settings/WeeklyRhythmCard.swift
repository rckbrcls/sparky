import SwiftUI

struct WeeklyRhythmCard: View {
    let rhythm: MeMetrics.RhythmSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your rhythm")
                .font(.title3)
                .bold()

            rhythmRows
        }
        .padding(20)
        .cardStyle(cornerRadius: 20)
    }
}

private extension WeeklyRhythmCard {
    var rhythmRows: some View {
        VStack(spacing: 16) {
            let periodText = MeMetrics.activityPeriodText(
                for: rhythm.mostActivePeriod
            )
            metricRow(
                title: "Most active period",
                value: periodText,
                accessibilityValue: MeMetrics.accessibilityText(
                    for: periodText
                )
            )
            Divider()
            let weekdayText = MeMetrics.weekdayText(for: rhythm.bestWeekday)
            metricRow(
                title: "Best completion day",
                value: weekdayText,
                accessibilityValue: MeMetrics.accessibilityText(
                    for: weekdayText
                )
            )
        }
    }

    func metricRow(
        title: String,
        value: String,
        accessibilityValue: String
    ) -> some View {
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
    }
}

#Preview("Measured Rhythm") {
    WeeklyRhythmCard(
        rhythm: MeMetrics.RhythmSummary(
            sampleCount: 5,
            mostActivePeriod: .morning,
            bestWeekday: 2
        )
    )
    .padding()
    .background(Color.Theme.secondaryBackground)
}

#Preview("Unavailable Rhythm") {
    WeeklyRhythmCard(
        rhythm: MeMetrics.RhythmSummary(
            sampleCount: 0,
            mostActivePeriod: nil,
            bestWeekday: nil
        )
    )
    .padding()
    .background(Color.Theme.secondaryBackground)
}

#Preview("Tied Rhythm") {
    WeeklyRhythmCard(
        rhythm: MeMetrics.RhythmSummary(
            sampleCount: 4,
            mostActivePeriod: nil,
            bestWeekday: nil
        )
    )
    .padding()
    .background(Color.Theme.secondaryBackground)
}
