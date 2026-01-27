//
//  ICalExportFormat.swift
//  i-cant-miss
//
//  Created by Codex on 26/01/26.
//

import Foundation
import os.log

/// iCalendar (RFC 5545) export format converter
/// Only supports memories with scheduled triggers (no location, person, or sequential triggers)
struct ICalExportFormat {
    static func convert(memories: [MemoryModel]) -> String {
        var lines: [String] = []
        
        // iCalendar header
        lines.append("BEGIN:VCALENDAR")
        lines.append("VERSION:2.0")
        lines.append("PRODID:-//Sparky//i-cant-miss//EN")
        lines.append("CALSCALE:GREGORIAN")
        lines.append("METHOD:PUBLISH")
        
        // Convert each memory to VTODO
        for memory in memories {
            // Only export memories with scheduled triggers
            let scheduledTriggers = memory.triggers.filter { 
                $0.type == .scheduled && $0.isActive 
            }
            
            guard !scheduledTriggers.isEmpty else { continue }
            
            // Create a VTODO for each scheduled trigger
            for trigger in scheduledTriggers {
                lines.append(contentsOf: convertMemoryToVTODO(memory: memory, trigger: trigger))
            }
        }
        
        // iCalendar footer
        lines.append("END:VCALENDAR")
        
        return lines.joined(separator: "\r\n")
    }
    
    private static func convertMemoryToVTODO(memory: MemoryModel, trigger: MemoryTriggerModel) -> [String] {
        var lines: [String] = []
        
        lines.append("BEGIN:VTODO")
        
        // UID
        lines.append("UID:\(memory.id.uuidString)-\(trigger.id.uuidString)")
        
        // DTSTAMP (current time)
        lines.append("DTSTAMP:\(formatDate(Date()))")
        
        // SUMMARY (title)
        let escapedTitle = escapeText(memory.title)
        lines.append("SUMMARY:\(escapedTitle)")
        
        // DESCRIPTION (note/body)
        if let note = memory.note, !note.isEmpty {
            let escapedNote = escapeText(note)
            lines.append("DESCRIPTION:\(escapedNote)")
        } else if let body = memory.body, !body.isEmpty {
            let escapedBody = escapeText(body)
            lines.append("DESCRIPTION:\(escapedBody)")
        }
        
        // STATUS
        let status = memory.status == .completed ? "COMPLETED" : "NEEDS-ACTION"
        lines.append("STATUS:\(status)")
        
        // COMPLETED (if completed)
        if memory.status == .completed {
            lines.append("COMPLETED:\(formatDate(memory.updatedAt))")
        }
        
        // DUE (due date if exists)
        if let dueDate = memory.dueDate {
            lines.append("DUE:\(formatDate(dueDate))")
        }
        
        // DTSTART (fire date)
        if let fireDate = trigger.fireDate {
            if trigger.isAllDay {
                lines.append("DTSTART;VALUE=DATE:\(formatDateOnly(fireDate))")
            } else {
                lines.append("DTSTART:\(formatDate(fireDate))")
            }
        }
        
        // RRULE (recurrence rule)
        if let recurrence = trigger.recurrenceRule {
            let rrule = formatRRULE(recurrence: recurrence, weekdayMask: trigger.weekdayMask)
            lines.append("RRULE:\(rrule)")
        } else if trigger.weekdayMask != 0 {
            // Weekday mask without recurrence
            let rrule = formatWeekdayMask(weekdayMask: trigger.weekdayMask, fireDate: trigger.fireDate)
            if !rrule.isEmpty {
                lines.append("RRULE:\(rrule)")
            }
        }
        
        // PRIORITY (if applicable)
        // iCal uses 0-9, where 0 is undefined, 1 is highest, 9 is lowest
        // We'll skip priority for now as it's not directly mapped
        
        // CREATED
        lines.append("CREATED:\(formatDate(memory.createdAt))")
        
        // LAST-MODIFIED
        lines.append("LAST-MODIFIED:\(formatDate(memory.updatedAt))")
        
        lines.append("END:VTODO")
        
        return lines
    }
    
    private static func formatDate(_ date: Date) -> String {
        // iCal format: YYYYMMDDTHHMMSSZ (UTC)
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: date)
        
        guard let year = components.year,
              let month = components.month,
              let day = components.day,
              let hour = components.hour,
              let minute = components.minute,
              let second = components.second else {
            return formatDateOnly(date) + "T000000Z"
        }
        
        return String(format: "%04d%02d%02dT%02d%02d%02dZ", year, month, day, hour, minute, second)
    }
    
    private static func formatDateOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
    
    private static func formatRRULE(recurrence: RecurrenceRule, weekdayMask: Int16) -> String {
        var components: [String] = []
        
        // FREQ
        let freq: String
        switch recurrence.frequency {
        case .minutely: freq = "MINUTELY"
        case .hourly: freq = "HOURLY"
        case .daily: freq = "DAILY"
        case .weekly: freq = "WEEKLY"
        case .monthly: freq = "MONTHLY"
        case .yearly: freq = "YEARLY"
        }
        components.append("FREQ=\(freq)")
        
        // INTERVAL
        if recurrence.interval > 1 {
            components.append("INTERVAL=\(recurrence.interval)")
        }
        
        // BYDAY (for weekday mask)
        if weekdayMask != 0 {
            let days = weekdayMaskToDays(weekdayMask)
            if !days.isEmpty {
                components.append("BYDAY=\(days.joined(separator: ","))")
            }
        }
        
        // UNTIL (end date) - format without time for date-only
        if let endDate = recurrence.endDate {
            components.append("UNTIL=\(formatDateOnly(endDate))")
        }
        
        return components.joined(separator: ";")
    }
    
    private static func formatWeekdayMask(weekdayMask: Int16, fireDate: Date?) -> String {
        guard weekdayMask != 0 else { return "" }
        
        let days = weekdayMaskToDays(weekdayMask)
        guard !days.isEmpty else { return "" }
        
        var components: [String] = []
        components.append("FREQ=WEEKLY")
        components.append("BYDAY=\(days.joined(separator: ","))")
        
        return components.joined(separator: ";")
    }
    
    private static func weekdayMaskToDays(_ mask: Int16) -> [String] {
        // iCal uses: SU, MO, TU, WE, TH, FR, SA
        // iOS Calendar uses: 1=Sunday, 2=Monday, ..., 7=Saturday
        let dayMap: [Int: String] = [
            1: "SU", // Sunday
            2: "MO", // Monday
            3: "TU", // Tuesday
            4: "WE", // Wednesday
            5: "TH", // Thursday
            6: "FR", // Friday
            7: "SA"  // Saturday
        ]
        
        var days: [String] = []
        for day in 1...7 {
            let bit = 1 << day
            if (mask & Int16(bit)) != 0 {
                if let dayName = dayMap[day] {
                    days.append(dayName)
                }
            }
        }
        
        return days
    }
    
    private static func escapeText(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

// MARK: - Extension for DataExportService

extension DataExportService {
    func exportToICal() async throws -> String {
        // Collect only memories with scheduled triggers
        let allMemories = await collectMemories(includeCompleted: true)
        let scheduledMemories = allMemories.filter { memory in
            memory.triggers.contains { $0.type == MemoryTriggerType.scheduled && $0.isActive }
        }
        
        guard !scheduledMemories.isEmpty else {
            throw ExportError.noDataToExport
        }
        
        return ICalExportFormat.convert(memories: scheduledMemories)
    }
    
    func exportToICalFile(at url: URL) async throws {
        let icalContent = try await exportToICal()
        let data = icalContent.data(using: .utf8) ?? Data()
        
        do {
            try data.write(to: url, options: .atomic)
            logger.info("Successfully exported iCal to: \(url.path)")
        } catch {
            logger.error("Failed to write iCal file: \(error.localizedDescription)")
            throw ExportError.fileWriteFailed(error)
        }
    }
}
