//
//  InfiniteScrollModifier.swift
//  i-cant-miss
//
//  Created by Codex on 26/11/25.
//

import SwiftUI
import Combine

/// A view that triggers loading more content when it appears on screen
struct InfiniteScrollSentinel: View {
    let onAppear: () -> Void

    var body: some View {
        Color.clear
            .frame(height: 50)  // Larger area for better scroll detection
            .onAppear {
                onAppear()
            }
    }
}

/// Configuration for infinite scroll behavior
struct InfiniteScrollConfig {
    /// Number of items to load when expanding backward (into the past)
    let backwardBatchSize: Int

    /// Number of items to load when expanding forward (into the future)
    let forwardBatchSize: Int

    /// Debounce interval to prevent rapid consecutive loads
    let debounceInterval: TimeInterval

    static let years = InfiniteScrollConfig(
        backwardBatchSize: 3,
        forwardBatchSize: 3,
        debounceInterval: 0.1
    )

    static let months = InfiniteScrollConfig(
        backwardBatchSize: 6,
        forwardBatchSize: 6,
        debounceInterval: 0.1
    )

    static let days = InfiniteScrollConfig(
        backwardBatchSize: 21,  // Increased from 14 for smoother scrolling
        forwardBatchSize: 21,   // Increased from 14 for smoother scrolling
        debounceInterval: 0.05  // Reduced from 0.1 for faster loading
    )
}

/// A state manager for infinite scroll ranges
@MainActor
final class InfiniteScrollState<T: Hashable>: ObservableObject {
    @Published private(set) var items: [T]
    @Published private(set) var isLoadingBackward = false
    @Published private(set) var isLoadingForward = false

    private let generateBackward: (T, Int) -> [T]
    private let generateForward: (T, Int) -> [T]
    private let config: InfiniteScrollConfig
    private var lastBackwardLoad: Date = .distantPast
    private var lastForwardLoad: Date = .distantPast

    init(
        initialItems: [T],
        config: InfiniteScrollConfig,
        generateBackward: @escaping (T, Int) -> [T],
        generateForward: @escaping (T, Int) -> [T]
    ) {
        self.items = initialItems
        self.config = config
        self.generateBackward = generateBackward
        self.generateForward = generateForward
    }

    func loadMoreBackward() {
        let now = Date()
        guard now.timeIntervalSince(lastBackwardLoad) > config.debounceInterval,
              !isLoadingBackward,
              let firstItem = items.first else {
            return
        }

        isLoadingBackward = true
        lastBackwardLoad = now

        let newItems = generateBackward(firstItem, config.backwardBatchSize)
        if !newItems.isEmpty {
            items = newItems + items
        }

        isLoadingBackward = false
    }

    func loadMoreForward() {
        let now = Date()
        guard now.timeIntervalSince(lastForwardLoad) > config.debounceInterval,
              !isLoadingForward,
              let lastItem = items.last else {
            return
        }

        isLoadingForward = true
        lastForwardLoad = now

        let newItems = generateForward(lastItem, config.forwardBatchSize)
        if !newItems.isEmpty {
            items = items + newItems
        }

        isLoadingForward = false
    }

    func reset(to newItems: [T]) {
        items = newItems
        lastBackwardLoad = .distantPast
        lastForwardLoad = .distantPast
    }
}

// MARK: - Year Scroll State

extension InfiniteScrollState where T == Int {
    /// Creates an infinite scroll state for years
    static func years(
        initialYear: Int,
        range: Int = 2,
        onLoadYear: @escaping (Int) -> Void
    ) -> InfiniteScrollState<Int> {
        let initialItems = Array((initialYear - range)...(initialYear + range))

        return InfiniteScrollState(
            initialItems: initialItems,
            config: .years,
            generateBackward: { firstYear, count in
                let newYears = ((firstYear - count)..<firstYear).reversed().map { $0 }
                newYears.forEach { onLoadYear($0) }
                return newYears.reversed()
            },
            generateForward: { lastYear, count in
                let newYears = ((lastYear + 1)...(lastYear + count)).map { $0 }
                newYears.forEach { onLoadYear($0) }
                return newYears
            }
        )
    }
}

// MARK: - Month Scroll State

extension InfiniteScrollState where T == Date {
    /// Creates an infinite scroll state for months
    static func months(
        centerMonth: Date,
        range: Int = 6,
        calendar: Calendar = .current,
        onLoadMonth: @escaping (Date) -> Void
    ) -> InfiniteScrollState<Date> {
        var initialItems: [Date] = []
        for offset in -range...range {
            if let month = calendar.date(byAdding: .month, value: offset, to: centerMonth) {
                let normalized = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
                initialItems.append(normalized)
            }
        }

        return InfiniteScrollState(
            initialItems: initialItems,
            config: .months,
            generateBackward: { firstMonth, count in
                var newMonths: [Date] = []
                for offset in (1...count).reversed() {
                    if let month = calendar.date(byAdding: .month, value: -offset, to: firstMonth) {
                        let normalized = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
                        newMonths.append(normalized)
                        onLoadMonth(normalized)
                    }
                }
                return newMonths
            },
            generateForward: { lastMonth, count in
                var newMonths: [Date] = []
                for offset in 1...count {
                    if let month = calendar.date(byAdding: .month, value: offset, to: lastMonth) {
                        let normalized = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
                        newMonths.append(normalized)
                        onLoadMonth(normalized)
                    }
                }
                return newMonths
            }
        )
    }

    /// Creates an infinite scroll state for days
    static func days(
        centerDay: Date,
        range: Int = 7,
        calendar: Calendar = .current,
        onLoadDay: @escaping (Date) -> Void
    ) -> InfiniteScrollState<Date> {
        var initialItems: [Date] = []
        for offset in -range...range {
            if let day = calendar.date(byAdding: .day, value: offset, to: centerDay) {
                let normalized = calendar.startOfDay(for: day)
                initialItems.append(normalized)
            }
        }

        return InfiniteScrollState(
            initialItems: initialItems,
            config: .days,
            generateBackward: { firstDay, count in
                var newDays: [Date] = []
                for offset in (1...count).reversed() {
                    if let day = calendar.date(byAdding: .day, value: -offset, to: firstDay) {
                        let normalized = calendar.startOfDay(for: day)
                        newDays.append(normalized)
                        onLoadDay(normalized)
                    }
                }
                return newDays
            },
            generateForward: { lastDay, count in
                var newDays: [Date] = []
                for offset in 1...count {
                    if let day = calendar.date(byAdding: .day, value: offset, to: lastDay) {
                        let normalized = calendar.startOfDay(for: day)
                        newDays.append(normalized)
                        onLoadDay(normalized)
                    }
                }
                return newDays
            }
        )
    }
}
