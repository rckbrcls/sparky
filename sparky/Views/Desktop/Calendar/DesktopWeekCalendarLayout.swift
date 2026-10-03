import Foundation
import CoreGraphics

struct DesktopWeekTimeSpan: Equatable, Identifiable {
    var id: String
    var startMinute: Int
    var endMinute: Int
}

struct DesktopWeekTimeFrame: Equatable, Identifiable {
    var id: String
    var column: Int
    var columnCount: Int
    var y: CGFloat
    var height: CGFloat
}

enum DesktopWeekCalendarLayout {
    nonisolated static let hourHeight: CGFloat = 64
    nonisolated static let hoursPerDay = 24
    nonisolated static let defaultDurationMinutes = 60
    nonisolated static let defaultScrollHour = 7
    nonisolated static let allDayVisibleLimit = 3
    nonisolated static let scrollAnchorID = "desktop-week-scroll-anchor"

    nonisolated static var dayHeight: CGFloat {
        hourHeight * CGFloat(hoursPerDay)
    }

    nonisolated static var dayMinutes: Int {
        hoursPerDay * 60
    }

    nonisolated static func minutes(from date: Date, calendar: Calendar) -> Int {
        calendar.component(.hour, from: date) * 60
            + calendar.component(.minute, from: date)
    }

    nonisolated static func yOffset(minutes: Int) -> CGFloat {
        CGFloat(minutes) / 60 * hourHeight
    }

    nonisolated static func yOffset(for date: Date, calendar: Calendar) -> CGFloat {
        yOffset(minutes: minutes(from: date, calendar: calendar))
    }

    nonisolated static func initialScrollOffset(
        now: Date,
        weekContainsToday: Bool,
        viewportHeight: CGFloat,
        calendar: Calendar
    ) -> CGFloat {
        let target = weekContainsToday
            ? yOffset(for: now, calendar: calendar) - hourHeight
            : yOffset(minutes: defaultScrollHour * 60)
        let maxOffset = max(dayHeight - viewportHeight, 0)
        return min(max(target, 0), maxOffset)
    }

    nonisolated static func frames(for spans: [DesktopWeekTimeSpan]) -> [DesktopWeekTimeFrame] {
        let intervals = spans.map { span in
            let start = min(max(span.startMinute, 0), dayMinutes)
            let end = normalizedEnd(start: start, requestedEnd: span.endMinute)
            return (span: span, start: start, end: end)
        }
        .sorted { lhs, rhs in
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            if lhs.end != rhs.end { return lhs.end > rhs.end }
            return lhs.span.id < rhs.span.id
        }

        var columnEnds: [Int] = []
        var placed: [(id: String, start: Int, end: Int, column: Int)] = []

        for interval in intervals {
            if let column = columnEnds.firstIndex(where: { $0 <= interval.start }) {
                columnEnds[column] = interval.end
                placed.append((interval.span.id, interval.start, interval.end, column))
            } else {
                columnEnds.append(interval.end)
                placed.append((interval.span.id, interval.start, interval.end, columnEnds.count - 1))
            }
        }

        var clusters: [[(id: String, start: Int, end: Int, column: Int)]] = []
        var current: [(id: String, start: Int, end: Int, column: Int)] = []
        var clusterEnd = 0

        for item in placed {
            if current.isEmpty || item.start >= clusterEnd {
                if !current.isEmpty {
                    clusters.append(current)
                }
                current = [item]
                clusterEnd = item.end
            } else {
                current.append(item)
                clusterEnd = max(clusterEnd, item.end)
            }
        }
        if !current.isEmpty {
            clusters.append(current)
        }

        return clusters.flatMap { cluster in
            let columnCount = (cluster.map(\.column).max() ?? 0) + 1
            return cluster.map { item in
                DesktopWeekTimeFrame(
                    id: item.id,
                    column: item.column,
                    columnCount: columnCount,
                    y: yOffset(minutes: item.start),
                    height: CGFloat(item.end - item.start) / 60 * hourHeight
                )
            }
        }
    }

    private nonisolated static func normalizedEnd(start: Int, requestedEnd: Int) -> Int {
        let expanded = max(requestedEnd, start + defaultDurationMinutes)
        return min(max(expanded, start), dayMinutes)
    }
}
