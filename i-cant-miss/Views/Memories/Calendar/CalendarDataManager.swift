//
//  CalendarDataManager.swift
//  i-cant-miss
//
//  Created by Codex on 26/11/25.
//

import SwiftUI
import Combine

/// Calendar data manager with lazy loading by period for infinite scroll support
@MainActor
final class CalendarDataManager: ObservableObject {

    // MARK: - Private Properties

    private let memoryService: MemoryService
    private let calendar = Calendar.current

    /// Cache of memories grouped by day (start of day as key)
    private var memoriesByDay: [Date: [MemoryModel]] = [:]

    /// Cache of months that have memories
    private var monthsWithMemories: Set<Date> = []

    /// Track which years have been loaded
    private var loadedYears: Set<Int> = []

    /// Track which months have been loaded
    private var loadedMonths: Set<Date> = []

    /// Flag to track if initial load is complete
    @Published private(set) var isInitialLoadComplete = false

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(memoryService: MemoryService) {
        self.memoryService = memoryService
        setupObservers()
        loadInitialData()
    }

    // MARK: - Public Methods - Data Access

    /// Get memories for a specific date
    func memoriesForDate(_ date: Date) -> [MemoryModel] {
        let dayKey = calendar.startOfDay(for: date)
        return memoriesByDay[dayKey] ?? []
    }

    /// Get memories for a specific day number in a month
    func memoriesForDay(monthKey: Date, day: Int) -> [MemoryModel] {
        guard let dayDate = calendar.date(bySetting: .day, value: day, of: monthKey) else {
            return []
        }
        return memoriesForDate(dayDate)
    }

    /// Check if a month has any memories
    func hasMemoriesInMonth(_ month: Date) -> Bool {
        let monthKey = normalizeToMonth(month)
        return monthsWithMemories.contains(monthKey)
    }

    /// Get count of memories in a month
    func memoryCountInMonth(_ month: Date) -> Int {
        let monthKey = normalizeToMonth(month)
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return 0 }

        var count = 0
        for day in range {
            if let dayDate = calendar.date(bySetting: .day, value: day, of: monthKey) {
                count += memoriesForDate(dayDate).count
            }
        }
        return count
    }

    /// Get all memories for a specific month
    func memoriesInMonth(_ month: Date) -> [Date: [MemoryModel]] {
        let monthKey = normalizeToMonth(month)
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [:] }

        var result: [Date: [MemoryModel]] = [:]
        for day in range {
            if let dayDate = calendar.date(bySetting: .day, value: day, of: monthKey) {
                let dayKey = calendar.startOfDay(for: dayDate)
                let memories = memoriesByDay[dayKey] ?? []
                if !memories.isEmpty {
                    result[dayKey] = memories
                }
            }
        }
        return result
    }

    // MARK: - Public Methods - Lazy Loading

    /// Ensure a specific year's data is loaded
    func ensureYearLoaded(_ year: Int) {
        guard !loadedYears.contains(year) else { return }
        loadYear(year)
    }

    /// Ensure multiple years are loaded
    func ensureYearsLoaded(_ years: [Int]) {
        let yearsToLoad = years.filter { !loadedYears.contains($0) }
        for year in yearsToLoad {
            loadYear(year)
        }
    }

    /// Ensure a specific month's data is loaded
    func ensureMonthLoaded(_ month: Date) {
        let monthKey = normalizeToMonth(month)
        guard !loadedMonths.contains(monthKey) else { return }
        loadMonth(monthKey)
    }

    /// Ensure multiple months are loaded
    func ensureMonthsLoaded(_ months: [Date]) {
        let monthsToLoad = months.compactMap { normalizeToMonth($0) }.filter { !loadedMonths.contains($0) }
        for month in monthsToLoad {
            loadMonth(month)
        }
    }

    /// Check if a year is already loaded
    func isYearLoaded(_ year: Int) -> Bool {
        loadedYears.contains(year)
    }

    /// Check if a month is already loaded
    func isMonthLoaded(_ month: Date) -> Bool {
        let monthKey = normalizeToMonth(month)
        return loadedMonths.contains(monthKey)
    }

    /// Clear the cache and reset loaded tracking
    func clearCache() {
        memoriesByDay.removeAll()
        monthsWithMemories.removeAll()
        loadedYears.removeAll()
        loadedMonths.removeAll()
        isInitialLoadComplete = false
        loadInitialData()
    }

    // MARK: - Private Methods

    private func setupObservers() {
        memoryService.$lastRefreshed
            .dropFirst()
            .sink { [weak self] _ in
                self?.handleMemoryServiceRefresh()
            }
            .store(in: &cancellables)
    }

    private func handleMemoryServiceRefresh() {
        // Re-load all currently loaded years/months with fresh data
        let years = loadedYears
        let months = loadedMonths

        memoriesByDay.removeAll()
        monthsWithMemories.removeAll()
        loadedYears.removeAll()
        loadedMonths.removeAll()

        for year in years {
            loadYear(year)
        }
        for month in months {
            loadMonth(month)
        }
    }

    private func loadInitialData() {
        // Load current year and adjacent months for initial view
        let now = Date()
        let currentYear = calendar.component(.year, from: now)

        // Load current year
        loadYear(currentYear)

        isInitialLoadComplete = true
    }

    private func loadYear(_ year: Int) {
        guard !loadedYears.contains(year) else { return }

        guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let yearEndDay = calendar.date(from: DateComponents(year: year, month: 12, day: 31)),
              let yearEnd = calendar.date(byAdding: .day, value: 1, to: yearEndDay)?.addingTimeInterval(-1) else {
            return
        }

        loadMemoriesForRange(from: yearStart, to: yearEnd)
        loadedYears.insert(year)

        // Also mark all months of this year as loaded
        for month in 1...12 {
            if let monthDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)) {
                loadedMonths.insert(monthDate)
            }
        }
    }

    private func loadMonth(_ monthKey: Date) {
        guard !loadedMonths.contains(monthKey) else { return }

        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: monthKey)),
              let range = calendar.range(of: .day, in: .month, for: monthKey),
              let lastDay = calendar.date(byAdding: .day, value: range.count - 1, to: monthStart),
              let monthEnd = calendar.date(byAdding: .day, value: 1, to: lastDay)?.addingTimeInterval(-1) else {
            return
        }

        loadMemoriesForRange(from: monthStart, to: monthEnd)
        loadedMonths.insert(monthKey)
    }

    private func loadMemoriesForRange(from startDate: Date, to endDate: Date) {
        let scheduled = memoryService.scheduledMemories()

        for memory in scheduled {
            let occurrences = memory.dates(from: startDate, to: endDate)

            for occurrence in occurrences {
                let dayKey = calendar.startOfDay(for: occurrence)

                // Avoid duplicates
                if memoriesByDay[dayKey]?.contains(where: { $0.id == memory.id }) == true {
                    continue
                }

                memoriesByDay[dayKey, default: []].append(memory)

                let monthKey = normalizeToMonth(occurrence)
                monthsWithMemories.insert(monthKey)
            }
        }

        // Sort memories within each affected day by fire date
        let dayCount = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        var affectedDays: Set<Date> = []
        for offset in 0...dayCount {
            if let date = calendar.date(byAdding: .day, value: offset, to: startDate) {
                affectedDays.insert(calendar.startOfDay(for: date))
            }
        }

        for dayKey in affectedDays where memoriesByDay[dayKey] != nil {
            memoriesByDay[dayKey]?.sort { lhs, rhs in
                let lhsDate = lhs.nextFireDate(referenceDate: dayKey) ?? .distantFuture
                let rhsDate = rhs.nextFireDate(referenceDate: dayKey) ?? .distantFuture
                return lhsDate < rhsDate
            }
        }
    }

    private func normalizeToMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
}
