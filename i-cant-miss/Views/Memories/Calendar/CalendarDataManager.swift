//
//  CalendarDataManager.swift
//  i-cant-miss
//
//  Created by Codex on 26/11/25.
//

import SwiftUI
import Combine

/// Simple synchronous calendar data manager with pre-computed cache
@MainActor
final class CalendarDataManager: ObservableObject {

    // MARK: - Private Properties

    private let memoryService: MemoryService
    private let calendar = Calendar.current

    /// Cache of memories grouped by day (start of day as key)
    private var memoriesByDay: [Date: [MemoryModel]] = [:]

    /// Cache of months that have memories
    private var monthsWithMemories: Set<Date> = []

    /// Track when cache was last built
    private var cacheDate: Date?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(memoryService: MemoryService) {
        self.memoryService = memoryService
        setupObservers()
        rebuildCache()
    }

    // MARK: - Public Methods

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

    /// Clear and rebuild the cache
    func rebuildCache() {
        memoriesByDay.removeAll()
        monthsWithMemories.removeAll()

        let scheduled = memoryService.scheduledMemories()

        // Build cache for a reasonable range (current year ± 1 year)
        let now = Date()
        let startYear = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        let endYear = calendar.date(byAdding: .year, value: 1, to: now) ?? now

        guard let rangeStart = calendar.date(from: calendar.dateComponents([.year], from: startYear)),
              let rangeEnd = calendar.date(byAdding: DateComponents(year: 2, day: -1), to: rangeStart) else {
            return
        }

        for memory in scheduled {
            let occurrences = memory.dates(from: rangeStart, to: rangeEnd)

            for occurrence in occurrences {
                let dayKey = calendar.startOfDay(for: occurrence)
                memoriesByDay[dayKey, default: []].append(memory)

                let monthKey = normalizeToMonth(occurrence)
                monthsWithMemories.insert(monthKey)
            }
        }

        // Sort memories within each day by fire date
        for dayKey in memoriesByDay.keys {
            memoriesByDay[dayKey]?.sort { lhs, rhs in
                let lhsDate = lhs.nextFireDate(referenceDate: dayKey) ?? .distantFuture
                let rhsDate = rhs.nextFireDate(referenceDate: dayKey) ?? .distantFuture
                return lhsDate < rhsDate
            }
        }

        cacheDate = Date()
    }

    /// Clear the cache
    func clearCache() {
        memoriesByDay.removeAll()
        monthsWithMemories.removeAll()
        cacheDate = nil
        rebuildCache()
    }

    // MARK: - Private Methods

    private func setupObservers() {
        memoryService.$lastRefreshed
            .dropFirst()
            .sink { [weak self] _ in
                self?.rebuildCache()
            }
            .store(in: &cancellables)
    }

    private func normalizeToMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
}
