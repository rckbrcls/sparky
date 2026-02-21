import Foundation

func weekdayMaskSummary(mask: Int16) -> String {
    guard mask != 0 else { return "No days selected" }

    // Define common patterns (Sunday=1, Monday=2, ..., Saturday=7)
    let allDaysMask: Int16 = 0b11111110  // Days 1-7
    let weekdaysMask: Int16 = 0b01111100  // Mon(2), Tue(3), Wed(4), Thu(5), Fri(6)
    let weekendMask: Int16 = 0b10000010   // Sun(1), Sat(7)

    // Check for common patterns
    if mask == allDaysMask {
        return "Every day"
    } else if mask == weekdaysMask {
        return "Weekdays"
    } else if mask == weekendMask {
        return "Weekend"
    }

    // Fall back to listing individual days
    let formatter = DateFormatter()
    let symbols = formatter.shortWeekdaySymbols ?? []
    guard !symbols.isEmpty else { return "No days selected" }
    let days = (1...7).compactMap { day -> String? in
        let bit = Int16(1 << day)
        guard mask & bit != 0 else { return nil }
        return symbols[(day - 1) % symbols.count]
    }
    return days.isEmpty ? "No days selected" : days.joined(separator: ", ")
}
