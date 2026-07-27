#if os(macOS)

import SwiftUI

struct DesktopDayCalendarView: View {
    @ObservedObject var dataManager: CalendarDataManager
    @Binding var anchorDate: Date

    let onSelect: (Memory) -> Void
    let onEdit: (Memory) -> Void

    @State private var expandedPeriods = Set(CalendarTimePeriod.allCases)

    private let calendar = Calendar.current
    private let weekdayHeaderHeight: CGFloat = 54
    private let contentMaxWidth: CGFloat = 880

    private var days: [Date] {
        DesktopCalendarLayout.weekDates(
            containing: anchorDate,
            calendar: calendar
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            weekdayHeader

            Divider()
                .overlay(Color.Theme.separator)

            HStack(spacing: 0) {
                Spacer(minLength: 0)

                CalendarDayContentView(
                    day: anchorDate,
                    dataManager: dataManager,
                    isMultiSelecting: false,
                    selectedMemoryIDs: [],
                    isPerformingBulkAction: false,
                    onSelectMemory: onSelect,
                    onEditMemory: onEdit,
                    onToggleSelection: { _ in },
                    creationBehavior: .desktopPopover { target in
                        MemoryEditorRoute(
                            mode: .create(mind: nil, template: .blank),
                            initialScheduleConfig: target.scheduleDraft()
                        )
                    },
                    expandedPeriods: $expandedPeriods,
                    onEnsureMonthDataLoaded: {
                        dataManager.ensureMonthLoaded($0)
                    },
                    showsDayHeader: false,
                    bottomContentInset: 0
                )
                .frame(maxWidth: contentMaxWidth, maxHeight: .infinity)

                Spacer(minLength: 0)
            }
        }
        .background(Color.Theme.secondaryBackground)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                weekdayButton(for: day)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: weekdayHeaderHeight)
        .accessibilityElement(children: .contain)
    }

    private func weekdayButton(for day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: anchorDate)
        let isToday = calendar.isDateInToday(day)

        return Button {
            anchorDate = day
        } label: {
            HStack(spacing: 5) {
                Text(day.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.Theme.textSecondary)

                Text(day.formatted(.dateTime.day()))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        isSelected
                            ? Color.Theme.accentForeground
                            : Color.Theme.textPrimary
                    )
                    .frame(width: 32, height: 32)
                    .background {
                        if isSelected {
                            Circle().fill(Color.accentColor)
                        } else if isToday {
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 1.5)
                        }
                    }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(
            day.formatted(
                .dateTime.weekday(.wide).month(.wide).day().year()
            )
        )
        .accessibilityLabel(
            day.formatted(
                .dateTime.weekday(.wide).month(.wide).day().year()
            )
        )
        .accessibilityValue(isToday ? "Today" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#endif
