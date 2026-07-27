#if os(macOS)

import SwiftUI

struct DesktopCalendarView: View {
    @StateObject private var dataManager: CalendarDataManager
    @Binding private var mode: DesktopCalendarMode
    @Binding private var anchorDate: Date

    let onSelect: (Memory) -> Void
    let onEdit: (Memory) -> Void

    private let calendar = Calendar.current

    init(
        memoryService: MemoryService,
        mode: Binding<DesktopCalendarMode>,
        anchorDate: Binding<Date>,
        onSelect: @escaping (Memory) -> Void,
        onEdit: @escaping (Memory) -> Void
    ) {
        _dataManager = StateObject(
            wrappedValue: CalendarDataManager(memoryService: memoryService)
        )
        _mode = mode
        _anchorDate = anchorDate
        self.onSelect = onSelect
        self.onEdit = onEdit
    }

    var body: some View {
        VStack(spacing: 0) {
            DesktopCalendarHeader(
                anchorDate: anchorDate,
                onPrevious: { move(by: -1) },
                onToday: { anchorDate = Date() },
                onNext: { move(by: 1) }
            )

            switch mode {
            case .day:
                DesktopDayCalendarView(
                    dataManager: dataManager,
                    anchorDate: $anchorDate,
                    onSelect: onSelect,
                    onEdit: onEdit
                )
            case .month:
                DesktopMonthCalendarView(
                    dataManager: dataManager,
                    anchorDate: anchorDate,
                    onOpenDay: openDay
                )
            }
        }
        .background(Color.Theme.secondaryBackground)
        .onAppear(perform: loadVisibleMonths)
        .onChange(of: anchorDate) { _, _ in
            loadVisibleMonths()
        }
        .onChange(of: mode) { _, _ in
            loadVisibleMonths()
        }
    }

    private func move(by direction: Int) {
        anchorDate = DesktopCalendarLayout.shiftedAnchor(
            anchorDate,
            mode: mode,
            direction: direction,
            calendar: calendar
        )
    }

    private func openDay(at date: Date) {
        anchorDate = date
        mode = .day
    }

    private func loadVisibleMonths() {
        dataManager.ensureMonthsLoaded(
            DesktopCalendarLayout.monthsNeeded(
                for: anchorDate,
                mode: mode,
                calendar: calendar
            )
        )
    }
}

#endif
