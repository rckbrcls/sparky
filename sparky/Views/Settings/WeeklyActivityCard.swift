import SwiftUI

struct WeeklyActivityCard: View {
    let activityDays: [MeMetrics.ActivityDay]

    @State private var selectedDate: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Activity")
                    .font(.title3)
                    .bold()

                selectedDaySummary
            }

            periodLegend

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(activityDays) { day in
                    activityButton(for: day)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .cardStyle(cornerRadius: 20)
        .onAppear {
            if selectedDate == nil {
                selectedDate = activityDays.last?.date
            }
        }
        .onChange(of: activityDays.map(\.id)) { _, dates in
            guard let selectedDate, dates.contains(selectedDate) else {
                self.selectedDate = dates.last
                return
            }
        }
    }
}

private extension WeeklyActivityCard {
    var selectedDay: MeMetrics.ActivityDay? {
        activityDays.first { $0.date == selectedDate } ?? activityDays.last
    }

    var maximumDailyCount: Int {
        max(activityDays.map(\.completionCount).max() ?? 0, 1)
    }

    @ViewBuilder
    var selectedDaySummary: some View {
        if let selectedDay {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Self.fullWeekdayFormatter.string(from: selectedDay.date))
                        .font(.subheadline)
                        .bold()

                    Text("·")
                        .foregroundStyle(Color.Theme.textTertiary)

                    Text(summary(for: selectedDay))
                        .font(.subheadline)
                        .foregroundStyle(Color.Theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.fullWeekdayFormatter.string(from: selectedDay.date))
                        .font(.subheadline)
                        .bold()
                    Text(summary(for: selectedDay))
                        .font(.subheadline)
                        .foregroundStyle(Color.Theme.textSecondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    var periodLegend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                ForEach(MeMetrics.ActivityPeriod.allCases, id: \.self) { period in
                    periodLegendItem(period)
                }
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), alignment: .leading),
                    GridItem(.flexible(), alignment: .leading)
                ],
                alignment: .leading,
                spacing: 6
            ) {
                ForEach(MeMetrics.ActivityPeriod.allCases, id: \.self) { period in
                    periodLegendItem(period)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bar colors show morning, afternoon, evening, and night completions")
    }

    func periodLegendItem(_ period: MeMetrics.ActivityPeriod) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(period.color)
                .frame(width: 7, height: 7)
            Text(period.title)
                .font(.caption)
                .foregroundStyle(Color.Theme.textSecondary)
        }
    }

    func activityButton(for day: MeMetrics.ActivityDay) -> some View {
        let isSelected = selectedDay?.id == day.id

        return Button {
            withAnimation(
                reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 1)
            ) {
                selectedDate = day.date
            }
        } label: {
            VStack(spacing: 6) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    activityBar(for: day)
                }
                .frame(height: 68)

                Text(Self.narrowWeekdayFormatter.string(from: day.date))
                    .font(isSelected ? .caption.bold() : .caption)
                    .foregroundStyle(
                        isSelected
                            ? Color.Theme.textPrimary
                            : Color.Theme.textSecondary
                    )

                Capsule()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(width: 16, height: 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 96)
        .accessibilityLabel(Self.fullWeekdayFormatter.string(from: day.date))
        .accessibilityValue(accessibilityValue(for: day))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    func activityBar(for day: MeMetrics.ActivityDay) -> some View {
        if day.completionCount == 0 {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.Theme.border.opacity(0.72))
                .frame(maxWidth: 18)
                .frame(height: 8)
        } else {
            VStack(spacing: 2) {
                ForEach(
                    MeMetrics.ActivityPeriod.allCases.filter {
                        day.completionCount(for: $0) > 0
                    },
                    id: \.self
                ) { period in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(period.color)
                        .frame(
                            height: segmentHeight(
                                for: period,
                                in: day
                            )
                        )
                }
            }
            .frame(maxWidth: 18)
        }
    }

    func segmentHeight(
        for period: MeMetrics.ActivityPeriod,
        in day: MeMetrics.ActivityDay
    ) -> CGFloat {
        let fullBarHeight = max(
            16,
            64 * CGFloat(day.completionCount) / CGFloat(maximumDailyCount)
        )
        let proportion = CGFloat(day.completionCount(for: period))
            / CGFloat(day.completionCount)
        return max(5, fullBarHeight * proportion)
    }

    func summary(for day: MeMetrics.ActivityDay) -> String {
        guard day.completionCount > 0 else { return "No completions" }
        if let period = day.dominantPeriod {
            return "\(day.completionCount) completed · \(period.title) peak"
        }
        return "\(day.completionCount) completed"
    }

    func accessibilityValue(for day: MeMetrics.ActivityDay) -> String {
        guard day.completionCount > 0 else { return "No completions" }
        let details = MeMetrics.ActivityPeriod.allCases.compactMap { period -> String? in
            let count = day.completionCount(for: period)
            guard count > 0 else { return nil }
            return "\(period.title) \(count)"
        }
        return "\(day.completionCount) completed. " + details.joined(separator: ", ")
    }

    static let narrowWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEEE"
        return formatter
    }()

    static let fullWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE"
        return formatter
    }()
}
