import SwiftUI

struct ContributionCalendarCard: View {
    let activityDays: [MeMetrics.ActivityDay]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        GeometryReader { proxy in
            let layout = calendarLayout
            let spacing = weekSpacing
            let cellSize = cellSize(
                for: proxy.size.width,
                weekCount: layout.weeks.count,
                spacing: spacing
            )

            VStack(spacing: 10) {
                monthHeader(
                    layout: layout,
                    cellSize: cellSize,
                    spacing: spacing
                )

                calendarGrid(
                    layout: layout,
                    cellSize: cellSize,
                    spacing: spacing
                )

                legend
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 180 : 150)
        .padding(20)
        .cardStyle(cornerRadius: 20)
    }
}

private extension ContributionCalendarCard {
    var monthCount: Int {
        horizontalSizeClass == .compact ? 4 : 12
    }

    var weekSpacing: CGFloat {
        monthCount == 4 ? 3 : 2
    }

    var displayCalendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }

    var calendarLayout: ContributionCalendarLayout {
        ContributionCalendarLayout.make(
            activityDays: activityDays,
            through: activityDays.last?.date ?? Date(),
            monthCount: monthCount,
            calendar: displayCalendar
        )
    }

    func cellSize(
        for width: CGFloat,
        weekCount: Int,
        spacing: CGFloat
    ) -> CGFloat {
        guard weekCount > 0 else { return 8 }
        let weekSpacingWidth = CGFloat(max(weekCount - 1, 0)) * spacing
        let availableWidth = width
            - Self.weekdayLabelWidth
            - Self.weekdayLabelSpacing
            - weekSpacingWidth
        return max(5, min(14, floor(availableWidth / CGFloat(weekCount))))
    }

    func monthHeader(
        layout: ContributionCalendarLayout,
        cellSize: CGFloat,
        spacing: CGFloat
    ) -> some View {
        HStack(spacing: spacing) {
            ForEach(layout.weeks) { week in
                ZStack(alignment: .leading) {
                    if let monthStart = week.monthStart {
                        Text(Self.monthFormatter.string(from: monthStart))
                            .font(.caption2)
                            .foregroundStyle(Color.Theme.textSecondary)
                            .fixedSize()
                    }
                }
                .frame(width: cellSize, height: 14, alignment: .leading)
            }
        }
        .padding(
            .leading,
            Self.weekdayLabelWidth + Self.weekdayLabelSpacing
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }

    func calendarGrid(
        layout: ContributionCalendarLayout,
        cellSize: CGFloat,
        spacing: CGFloat
    ) -> some View {
        HStack(alignment: .top, spacing: Self.weekdayLabelSpacing) {
            weekdayLabels(
                layout.weekdayLabels,
                cellSize: cellSize,
                spacing: spacing
            )

            HStack(spacing: spacing) {
                ForEach(layout.weeks) { week in
                    VStack(spacing: spacing) {
                        ForEach(week.days) { day in
                            contributionCell(day, size: cellSize)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func weekdayLabels(
        _ labels: [String?],
        cellSize: CGFloat,
        spacing: CGFloat
    ) -> some View {
        VStack(spacing: spacing) {
            ForEach(labels.indices, id: \.self) { index in
                Text(labels[index] ?? "")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.Theme.textSecondary)
                    .lineLimit(1)
                    .frame(
                        width: Self.weekdayLabelWidth,
                        height: cellSize,
                        alignment: .leading
                    )
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    func contributionCell(
        _ day: ContributionCalendarLayout.Day,
        size: CGFloat
    ) -> some View {
        let cell = RoundedRectangle(
            cornerRadius: max(2, size * 0.22),
            style: .continuous
        )
        .fill(color(for: day))
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityHidden(day.completionCount == nil)
        .accessibilityLabel(Self.accessibilityDateFormatter.string(from: day.date))
        .accessibilityValue(completionDescription(for: day.completionCount))

        #if os(macOS)
        cell.help(tooltipDescription(for: day))
        #else
        cell
        #endif
    }

    var legend: some View {
        HStack(spacing: 5) {
            Text("Less")
            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(color(for: level))
                    .frame(width: 10, height: 10)
            }
            Text("More")
        }
        .font(.caption2)
        .foregroundStyle(Color.Theme.textSecondary)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Contribution intensity from less to more")
    }

    func color(for day: ContributionCalendarLayout.Day) -> Color {
        guard let level = day.intensityLevel else {
            return Color.Theme.border.opacity(0.22)
        }
        return color(for: level)
    }

    func color(for level: Int) -> Color {
        switch level {
        case 0:
            return Color.Theme.elementBackground
        case 1:
            return Color.accentColor.opacity(0.24)
        case 2:
            return Color.accentColor.opacity(0.44)
        case 3:
            return Color.accentColor.opacity(0.68)
        default:
            return Color.accentColor.opacity(0.92)
        }
    }

    func completionDescription(for count: Int?) -> String {
        guard let count else { return "" }
        switch count {
        case 0:
            return "No completions"
        case 1:
            return "1 completion"
        default:
            return "\(count) completions"
        }
    }

    func tooltipDescription(for day: ContributionCalendarLayout.Day) -> String {
        let date = Self.accessibilityDateFormatter.string(from: day.date)
        return "\(date): \(completionDescription(for: day.completionCount))"
    }

    static let weekdayLabelWidth: CGFloat = 28
    static let weekdayLabelSpacing: CGFloat = 6

    static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter
    }()

    static let accessibilityDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .long
        return formatter
    }()
}

#Preview {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let days = (0..<120).compactMap { offset -> MeMetrics.ActivityDay? in
        guard let date = calendar.date(
            byAdding: .day,
            value: offset - 119,
            to: today
        ) else {
            return nil
        }
        let count = offset % 6
        return MeMetrics.ActivityDay(
            date: date,
            periodCounts: count == 0 ? [:] : [.morning: count]
        )
    }

    ContributionCalendarCard(activityDays: days)
        .padding()
        .background(Color.Theme.secondaryBackground)
}
