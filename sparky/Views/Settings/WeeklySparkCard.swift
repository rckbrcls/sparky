import SwiftUI

struct WeeklySparkCard: View {
    let metrics: MeMetrics

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            weeklySummary
            Divider()
            metricSummary
            Divider()
            scheduledProgress
        }
        .padding(20)
        .cardStyle(cornerRadius: 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weekly Spark")
        .accessibilityValue(accessibilityValue)
    }
}

private extension WeeklySparkCard {
    var weeklySummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Weekly Spark")
                .font(.headline)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                completionCount
                Text("completed")
                    .font(.body)
                    .foregroundStyle(Color.Theme.textSecondary)
            }
        }
    }

    var completionCount: some View {
        Text("\(metrics.completionCountLast7Days)")
            .font(.custom("Baskerville", size: 48, relativeTo: .largeTitle))
            .bold()
            .contentTransition(.numericText())
    }

    var scheduledProgress: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Scheduled completion")
                Spacer()
                Text(completionRateText)
                    .bold()
            }
            .font(.caption)
            .foregroundStyle(Color.Theme.textSecondary)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.Theme.border)

                    if metrics.completionRate.isAvailable {
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(
                                width: geometry.size.width * metrics.completionRate.value
                            )
                    }
                }
            }
            .frame(height: 7)
            .animation(
                reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 1),
                value: metrics.completionRate.value
            )
        }
    }

    @ViewBuilder
    var metricSummary: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 12) {
                metricRow(
                    title: "Current streak",
                    value: dayCount(metrics.streakDays)
                )
                Divider()
                metricRow(
                    title: "Active days",
                    value: "\(metrics.activeDaysLast7Days)"
                )
                Divider()
                metricRow(
                    title: "All-time completed",
                    value: "\(metrics.totalCompletionCount)"
                )
            }
        } else {
            HStack(spacing: 12) {
                compactMetric(
                    title: "Streak",
                    value: "\(metrics.streakDays)d"
                )
                Divider()
                compactMetric(
                    title: "Active",
                    value: "\(metrics.activeDaysLast7Days)"
                )
                Divider()
                compactMetric(
                    title: "All time",
                    value: "\(metrics.totalCompletionCount)"
                )
            }
            .frame(minHeight: 54)
        }
    }

    func compactMetric(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom("Baskerville", size: 24, relativeTo: .title3))
                .bold()
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.Theme.textSecondary)
            Spacer()
            Text(value)
                .bold()
        }
        .font(.body)
    }

    func dayCount(_ count: Int) -> String {
        "\(count) \(count == 1 ? "day" : "days")"
    }

    var completionRateText: String {
        MeMetrics.percentageText(for: metrics.completionRate)
    }

    var accessibilityValue: String {
        var parts = [
            "\(metrics.completionCountLast7Days) completed this week",
            "\(metrics.activeDaysLast7Days) active days",
            "current streak \(dayCount(metrics.streakDays))",
            "\(metrics.totalCompletionCount) completed all time"
        ]
        parts.append(
            "scheduled completion \(MeMetrics.accessibilityText(for: completionRateText))"
        )
        return parts.joined(separator: ", ")
    }
}

#Preview("Scheduled Progress") {
    WeeklySparkCard(
        metrics: MeMetrics(
            memoryCount: 5,
            activityDays: [
                MeMetrics.ActivityDay(
                    date: Date(),
                    periodCounts: [.morning: 3]
                )
            ],
            completionRate: MeMetrics.CompletionRate(
                completedOccurrences: 3,
                scheduledOccurrences: 5
            ),
            streakDays: 2,
            totalCompletionCount: 18,
            rhythm: MeMetrics.RhythmSummary(
                sampleCount: 5,
                mostActivePeriod: .morning,
                bestWeekday: 2
            ),
            insight: .activePeriod(.morning)
        )
    )
    .padding()
    .background(Color.Theme.secondaryBackground)
}

#Preview("Unavailable Scheduled Progress") {
    WeeklySparkCard(
        metrics: MeMetrics(
            memoryCount: 0,
            activityDays: [],
            completionRate: MeMetrics.CompletionRate(
                completedOccurrences: 0,
                scheduledOccurrences: 0
            ),
            streakDays: 0,
            totalCompletionCount: 0,
            rhythm: MeMetrics.RhythmSummary(
                sampleCount: 0,
                mostActivePeriod: nil,
                bestWeekday: nil
            ),
            insight: .buildingPattern
        )
    )
    .padding()
    .background(Color.Theme.secondaryBackground)
}
