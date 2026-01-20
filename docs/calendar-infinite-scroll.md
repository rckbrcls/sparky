# Calendar Infinite Scroll

This document describes the implementation of infinite scroll for calendar views in the Timeline feature.

## Overview

The calendar views (Month, Day) use a lazy loading approach with infinite scroll, allowing users to navigate through time without loading all data upfront. This improves performance and memory usage significantly.

## Architecture

### Components

```
┌─────────────────────────────────────────────────────────────┐
│                    CalendarDataManager                       │
│  - Lazy loading by period (year/month)                       │
│  - Segmented cache (loadedYears, loadedMonths)              │
│  - On-demand data fetching                                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  InfiniteScrollState<T>                      │
│  - Generic state manager for scroll items                    │
│  - Handles backward/forward expansion                        │
│  - Debouncing to prevent rapid loads                         │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
┌──────────────────┐ ┌──────────────────┐
│CalendarMonthView │ │ CalendarDayView  │
│ - Months scroll  │ │ - Days scroll    │
│ - ±6 initial     │ │ - ±7 initial     │
│ - +6 expansion   │ │ - +14 expansion  │
└──────────────────┘ └──────────────────┘
```

## Files

| File | Description |
|------|-------------|
| `CalendarDataManager.swift` | Manages memory data with lazy loading by period |
| `InfiniteScrollModifier.swift` | Generic infinite scroll infrastructure |
| `CalendarMonthView.swift` | Month-level calendar with infinite scroll |
| `CalendarDayView.swift` | Day-level calendar with week grouping |

## CalendarDataManager

### Lazy Loading Strategy

Instead of loading all data at once, the manager loads data on-demand:

```swift
// Track which periods are loaded
private var loadedYears: Set<Int> = []
private var loadedMonths: Set<Date> = []

// Load a year's data only when needed
func ensureYearLoaded(_ year: Int) {
    guard !loadedYears.contains(year) else { return }
    loadYear(year)
}

// Load a month's data only when needed
func ensureMonthLoaded(_ month: Date) {
    let monthKey = normalizeToMonth(month)
    guard !loadedMonths.contains(monthKey) else { return }
    loadMonth(monthKey)
}
```

### Cache Invalidation

When the `MemoryService` refreshes, only previously loaded periods are reloaded:

```swift
private func handleMemoryServiceRefresh() {
    let years = loadedYears
    let months = loadedMonths

    // Clear caches
    memoriesByDay.removeAll()
    loadedYears.removeAll()
    loadedMonths.removeAll()

    // Reload only what was previously loaded
    for year in years { loadYear(year) }
    for month in months { loadMonth(month) }
}
```

## InfiniteScrollState

A generic state manager that handles the scroll item collection and expansion logic.

### Configuration

```swift
struct InfiniteScrollConfig {
    let backwardBatchSize: Int   // Items to load when scrolling up
    let forwardBatchSize: Int    // Items to load when scrolling down
    let debounceInterval: TimeInterval  // Prevent rapid consecutive loads

    static let months = InfiniteScrollConfig(
        backwardBatchSize: 6,
        forwardBatchSize: 6,
        debounceInterval: 0.1
    )

    static let days = InfiniteScrollConfig(
        backwardBatchSize: 14,
        forwardBatchSize: 14,
        debounceInterval: 0.1
    )
}
```

### Factory Methods

```swift
// For months
InfiniteScrollState.months(
    centerMonth: Date(),
    range: 6,  // ±6 months initially
    onLoadMonth: { month in dataManager.ensureMonthLoaded(month) }
)

// For days
InfiniteScrollState.days(
    centerDay: Date(),
    range: 7,  // ±7 days initially
    onLoadDay: { day in dataManager.ensureMonthLoaded(month) }
)
```

## Scroll Detection

Uses sentinel views at the top and bottom of the scroll content to detect when to load more:

```swift
LazyVStack(spacing: 24) {
    // Top sentinel - triggers backward loading
    InfiniteScrollSentinel {
        scrollState.loadMoreBackward()
    }

    ForEach(scrollState.items, id: \.self) { item in
        // Content views
    }

    // Bottom sentinel - triggers forward loading
    InfiniteScrollSentinel {
        scrollState.loadMoreForward()
    }
}
```

The `InfiniteScrollSentinel` is a simple invisible view:

```swift
struct InfiniteScrollSentinel: View {
    let onAppear: () -> Void

    var body: some View {
        Color.clear
            .frame(height: 1)
            .onAppear { onAppear() }
    }
}
```

## Day View: Week Grouping

The day view has special logic to group empty days into week summaries:

### Display Sections

```swift
enum DayDisplaySection {
    case weekSummary(startDate: Date, endDate: Date)  // "December 7 - 13"
    case day(Date)  // Individual day with memories
}
```

### Grouping Logic

1. Days are grouped by week (using `weekOfYear`)
2. For each week:
   - If no memories → show week summary ("December 7 - 13")
   - If has memories → show only days with memories

```swift
private func processWeek(_ days: [Date]) -> [DayDisplaySection] {
    let daysWithMemories = days.filter {
        !dataManager.memoriesForDate($0).isEmpty
    }

    if daysWithMemories.isEmpty {
        // Empty week - create summary
        return [.weekSummary(startDate: days.first!, endDate: days.last!)]
    } else {
        // Show only days with content
        return daysWithMemories.map { .day($0) }
    }
}
```

### Summary Format

The week summary adapts to date ranges:

| Scenario | Format |
|----------|--------|
| Same month | "December 7 - 13" |
| Different months | "Dec 28 - Jan 3" |
| Different years | "Dec 28, 2024 - Jan 3, 2025" |

## Performance Benefits

1. **Memory**: Cache grows only as needed, not pre-allocated for years of data
2. **Startup**: Initial load is fast (only current year/month/week)
3. **Scrolling**: Smooth infinite scroll in both directions
4. **Responsiveness**: Data loads incrementally as user navigates

## Initial Ranges

| View | Initial Range | Expansion Size |
|------|---------------|----------------|
| Month | Current month ± 6 months | +6 months |
| Day | Current day ± 7 days | +14 days |
