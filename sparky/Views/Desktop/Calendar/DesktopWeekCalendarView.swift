#if os(macOS)

import SwiftUI

struct DesktopWeekCalendarView: View {
    @ObservedObject var dataManager: CalendarDataManager

    let anchorDate: Date
    let onOpenDay: (Date) -> Void

    private let calendar = Calendar.current
    private let gutterWidth: CGFloat = 64
    private let dayHeaderHeight: CGFloat = 58

    private var days: [Date] {
        DesktopCalendarLayout.weekDates(containing: anchorDate, calendar: calendar)
    }

    var body: some View {
        VStack(spacing: 0) {
            dayHeader

            allDayBand

            Rectangle()
                .fill(Color.Theme.separator)
                .frame(height: 1)

            GeometryReader { geometry in
                let columnWidth = max(
                    (geometry.size.width - gutterWidth) / CGFloat(max(days.count, 1)),
                    0
                )
                hourGrid(
                    columnWidth: columnWidth,
                    viewportHeight: geometry.size.height
                )
            }
        }
        .background(Color.Theme.secondaryBackground)
    }

    private var dayHeader: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: gutterWidth, height: dayHeaderHeight)

            ForEach(days, id: \.self) { day in
                dayHeaderButton(day)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: dayHeaderHeight)
        .accessibilityElement(children: .contain)
    }

    private var allDayBand: some View {
        HStack(alignment: .top, spacing: 0) {
            Text("all-day")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.Theme.textSecondary)
                .frame(width: gutterWidth, alignment: .trailing)
                .padding(.trailing, 8)
                .padding(.top, 8)

            ForEach(days, id: \.self) { day in
                DesktopWeekAllDayColumn(occurrences: allDayOccurrences(for: day))
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color.Theme.separator)
                            .frame(width: 1)
                    }
            }
        }
        .frame(height: allDayBandHeight, alignment: .top)
        .accessibilityElement(children: .contain)
    }

    private func hourGrid(columnWidth: CGFloat, viewportHeight: CGFloat) -> some View {
        let scrollTarget = DesktopWeekCalendarLayout.initialScrollOffset(
            now: Date(),
            weekContainsToday: days.contains { calendar.isDateInToday($0) },
            viewportHeight: viewportHeight,
            calendar: calendar
        )

        return ScrollViewReader { proxy in
            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 0) {
                    hourGutter
                        .frame(width: gutterWidth)

                    ForEach(days, id: \.self) { day in
                        DesktopWeekDayColumn(
                            day: day,
                            dataManager: dataManager,
                            columnWidth: columnWidth
                        )
                        .frame(width: columnWidth, height: DesktopWeekCalendarLayout.dayHeight)
                    }
                }
                .frame(height: DesktopWeekCalendarLayout.dayHeight, alignment: .top)
                .overlay(alignment: .topLeading) {
                    nowLine(columnWidth: columnWidth)
                        .padding(.leading, gutterWidth)
                        .allowsHitTesting(false)
                }
                .background(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: scrollTarget)
                        Color.clear
                            .frame(width: 1, height: 1)
                            .id(DesktopWeekCalendarLayout.scrollAnchorID)
                    }
                    .allowsHitTesting(false)
                }
            }
            .task(id: anchorDate) {
                await Task.yield()
                proxy.scrollTo(DesktopWeekCalendarLayout.scrollAnchorID, anchor: .top)
            }
        }
    }

    private var hourGutter: some View {
        VStack(spacing: 0) {
            ForEach(0..<DesktopWeekCalendarLayout.hoursPerDay, id: \.self) { hour in
                Text(hourLabel(hour))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 8)
                    .frame(height: DesktopWeekCalendarLayout.hourHeight, alignment: .top)
                    .offset(y: hour == 0 ? 4 : -6)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func nowLine(columnWidth: CGFloat) -> some View {
        if let todayIndex = days.firstIndex(where: { calendar.isDateInToday($0) }) {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let y = DesktopWeekCalendarLayout.yOffset(
                    for: context.date,
                    calendar: calendar
                )

                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(height: 1.5)
                        .offset(y: y)

                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 7, height: 7)
                        .offset(
                            x: CGFloat(todayIndex) * columnWidth - 3,
                            y: y - 2.75
                        )
                }
            }
        }
    }

    private func dayHeaderButton(_ day: Date) -> some View {
        let isToday = calendar.isDateInToday(day)

        return Button {
            onOpenDay(day)
        } label: {
            VStack(spacing: 2) {
                Text(day.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isToday ? Color.accentColor : Color.Theme.textSecondary)

                Text(day.formatted(.dateTime.day()))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        isToday ? Color.Theme.accentForeground : Color.Theme.textPrimary
                    )
                    .frame(width: 28, height: 28)
                    .background {
                        if isToday {
                            Circle().fill(Color.accentColor)
                        }
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .help("Open day")
        .accessibilityLabel(
            day.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
        )
        .accessibilityValue(isToday ? "Today" : "")
    }

    private func hourLabel(_ hour: Int) -> String {
        let start = calendar.startOfDay(for: anchorDate)
        let date = calendar.date(byAdding: .hour, value: hour, to: start) ?? start
        return date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
    }

    private func allDayOccurrences(for day: Date) -> [MemoryOccurrence] {
        dataManager.occurrencesForDate(day).filter(\.isAllDay)
    }

    private var allDayBandHeight: CGFloat {
        let limit = DesktopWeekCalendarLayout.allDayVisibleLimit
        let visibleRows = days
            .map { min(allDayOccurrences(for: $0).count, limit) }
            .max() ?? 0
        let showsOverflow = days.contains { allDayOccurrences(for: $0).count > limit }
        let rows = CGFloat(max(visibleRows, 1))
        let gaps = CGFloat(max(visibleRows - 1, 0)) * 4
        let overflowHeight: CGFloat = showsOverflow ? 18 : 0
        return 16 + rows * 22 + gaps + overflowHeight
    }
}

private struct DesktopWeekDayColumn: View {
    let day: Date
    @ObservedObject var dataManager: CalendarDataManager
    let columnWidth: CGFloat

    @State private var createRoute: MemoryEditorRoute?
    @State private var createHour: Int?

    private let calendar = Calendar.current

    var body: some View {
        ZStack(alignment: .topLeading) {
            hourCells
            timedCards
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.Theme.separator)
                .frame(width: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var hourCells: some View {
        VStack(spacing: 0) {
            ForEach(0..<DesktopWeekCalendarLayout.hoursPerDay, id: \.self) { hour in
                Color.clear
                    .frame(height: DesktopWeekCalendarLayout.hourHeight)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        createMemory(at: hour)
                    }
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Color.Theme.separator)
                            .frame(height: 1)
                    }
                    .overlay {
                        if createHour == hour {
                            Color.clear
                                .desktopMemoryEditorPopover(item: $createRoute)
                        }
                    }
                    .accessibilityLabel(createAccessibilityLabel(hour: hour))
                    .accessibilityAddTraits(.isButton)
            }
        }
    }

    private var timedCards: some View {
        let cards = timedCardModels
        let frames = Dictionary(
            uniqueKeysWithValues: DesktopWeekCalendarLayout.frames(
                for: cards.map {
                    DesktopWeekTimeSpan(
                        id: $0.id,
                        startMinute: $0.startMinute,
                        endMinute: $0.endMinute
                    )
                }
            ).map { ($0.id, $0) }
        )

        return ZStack(alignment: .topLeading) {
            ForEach(cards) { card in
                if let frame = frames[card.id] {
                    let laneWidth = columnWidth / CGFloat(frame.columnCount)
                    DesktopWeekEventCard(
                        memory: card.memory,
                        start: card.start,
                        timeLabel: card.timeLabel
                    )
                    .frame(
                        width: max(laneWidth - 4, 0),
                        height: max(frame.height - 2, 1)
                    )
                    .offset(
                        x: CGFloat(frame.column) * laneWidth + 2,
                        y: frame.y + 1
                    )
                }
            }
        }
    }

    private var timedCardModels: [DesktopWeekTimedCard] {
        let occurrences = dataManager.occurrencesForDate(day).filter { !$0.isAllDay }
        return CalendarPeriodEntries.make(from: occurrences).compactMap { entry in
            switch entry {
            case .single(let occurrence):
                let minute = DesktopWeekCalendarLayout.minutes(
                    from: occurrence.occurrenceDate,
                    calendar: calendar
                )
                return DesktopWeekTimedCard(
                    id: occurrence.id,
                    memory: occurrence.memory,
                    start: occurrence.occurrenceDate,
                    timeLabel: occurrence.occurrenceDate.formatted(
                        date: .omitted,
                        time: .shortened
                    ),
                    startMinute: minute,
                    endMinute: minute
                )
            case .series(let series):
                guard let start = series.rangeStart else { return nil }
                let end = series.rangeEnd ?? start
                return DesktopWeekTimedCard(
                    id: entry.id,
                    memory: series.memory,
                    start: start,
                    timeLabel: series.timeRangeLabel,
                    startMinute: DesktopWeekCalendarLayout.minutes(
                        from: start,
                        calendar: calendar
                    ),
                    endMinute: DesktopWeekCalendarLayout.minutes(
                        from: end,
                        calendar: calendar
                    )
                )
            }
        }
    }

    private func createMemory(at hour: Int) {
        let target = CalendarQuickMemoryTarget(
            exact: fireDate(hour: hour),
            calendar: calendar
        )
        createHour = hour
        createRoute = MemoryEditorRoute(
            mode: .create(mind: nil, template: .blank),
            initialScheduleConfig: target.scheduleDraft(calendar: calendar)
        )
    }

    private func fireDate(hour: Int) -> Date {
        let start = calendar.startOfDay(for: day)
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: start)
            ?? calendar.date(byAdding: .hour, value: hour, to: start)
            ?? start
    }

    private func createAccessibilityLabel(hour: Int) -> String {
        let time = fireDate(hour: hour).formatted(date: .omitted, time: .shortened)
        let dayLabel = day.formatted(.dateTime.weekday(.wide).month(.wide).day())
        return "New Memory, \(dayLabel), \(time)"
    }
}

private struct DesktopWeekTimedCard: Identifiable {
    let id: String
    let memory: Memory
    let start: Date
    let timeLabel: String
    let startMinute: Int
    let endMinute: Int
}

private struct DesktopWeekAllDayColumn: View {
    let occurrences: [MemoryOccurrence]

    private var visibleOccurrences: [MemoryOccurrence] {
        Array(occurrences.prefix(DesktopWeekCalendarLayout.allDayVisibleLimit))
    }

    private var overflowOccurrences: [MemoryOccurrence] {
        Array(occurrences.dropFirst(DesktopWeekCalendarLayout.allDayVisibleLimit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(visibleOccurrences) { occurrence in
                DesktopWeekAllDayChip(occurrence: occurrence)
            }

            if !overflowOccurrences.isEmpty {
                DesktopCalendarOverflowButton(occurrences: overflowOccurrences)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct DesktopWeekAllDayChip: View {
    let occurrence: MemoryOccurrence

    @State private var editorRoute: MemoryEditorRoute?

    private var title: String {
        let trimmed = occurrence.memory.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    private var isCompleted: Bool {
        occurrence.memory.isCompleted(for: occurrence.occurrenceDate)
    }

    var body: some View {
        Button {
            editorRoute = MemoryEditorRoute(mode: .edit(memory: occurrence.memory))
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(CalendarColorHelper.color(for: occurrence.memory))
                    .frame(width: 8, height: 8)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        isCompleted ? Color.Theme.textTertiary : Color.Theme.textPrimary
                    )
                    .strikethrough(isCompleted, color: Color.Theme.textTertiary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.Theme.tertiaryBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.Theme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel("\(title), All day")
        .desktopMemoryEditorPopover(item: $editorRoute)
    }
}

private struct DesktopWeekEventCard: View {
    let memory: Memory
    let start: Date
    let timeLabel: String

    @State private var editorRoute: MemoryEditorRoute?

    private var title: String {
        let trimmed = memory.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    private var isCompleted: Bool {
        memory.isCompleted(for: start)
    }

    var body: some View {
        Button {
            editorRoute = MemoryEditorRoute(mode: .edit(memory: memory))
        } label: {
            HStack(alignment: .top, spacing: 6) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(CalendarColorHelper.color(for: memory))
                    .frame(width: 3)
                    .frame(maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(
                            isCompleted ? Color.Theme.textTertiary : Color.Theme.textPrimary
                        )
                        .strikethrough(isCompleted, color: Color.Theme.textTertiary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(timeLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.Theme.tertiaryBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.Theme.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("\(title), \(timeLabel)")
        .accessibilityLabel("\(title), \(timeLabel)")
        .desktopMemoryEditorPopover(item: $editorRoute)
    }
}

#endif
