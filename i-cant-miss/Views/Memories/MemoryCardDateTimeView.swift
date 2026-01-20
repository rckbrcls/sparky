//
//  MemoryCardDateTimeView.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import SwiftUI

struct MemoryCardDateTimeView: View {
    let trigger: MemoryTriggerModel
    let isCompletedForDisplay: Bool
    
    private var fireDate: Date? {
        trigger.fireDate
    }
    
    private var dateString: String {
        guard let fireDate = fireDate else { return "" }
        return fireDate.formatted(date: .abbreviated, time: .omitted)
    }
    
    private var timeString: String? {
        guard let fireDate = fireDate, !trigger.isAllDay else { return nil }
        return fireDate.formatted(date: .omitted, time: .shortened)
    }
    
    private var recurrenceString: String? {
        // Priorize weekdayMask se existir
        if trigger.weekdayMask != 0 {
            return weekdayMaskSummary(mask: trigger.weekdayMask)
        }
        
        // Caso contrário, use recurrenceRule
        guard let recurrence = trigger.recurrenceRule else {
            return nil
        }
        
        let frequencyText: String
        switch recurrence.frequency {
        case .daily:
            frequencyText = "Daily"
        case .weekly:
            frequencyText = recurrence.interval > 1 ? "Every \(recurrence.interval) weeks" : "Weekly"
        case .monthly:
            frequencyText = recurrence.interval > 1 ? "Every \(recurrence.interval) months" : "Monthly"
        case .yearly:
            frequencyText = recurrence.interval > 1 ? "Every \(recurrence.interval) years" : "Yearly"
        case .hourly:
            frequencyText = recurrence.interval > 1 ? "Every \(recurrence.interval) hours" : "Hourly"
        case .minutely:
            frequencyText = recurrence.interval > 1 ? "Every \(recurrence.interval) minutes" : "Minutely"
        }
        
        return frequencyText
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Calendar icon
            Image(systemName: "calendar")
                .font(.caption)
                .foregroundStyle(isCompletedForDisplay ? .secondary : .primary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                // Date and time
                HStack(spacing: 8) {
                    Text(dateString)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(isCompletedForDisplay ? .secondary : .primary)
                        .strikethrough(isCompletedForDisplay, color: .secondary)
                    
                    if let timeString = timeString {
                        Text(timeString)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(isCompletedForDisplay ? .secondary : .primary)
                            .strikethrough(isCompletedForDisplay, color: .secondary)
                    }
                }
                
                // Recurrence
                if let recurrenceString = recurrenceString {
                    Text(recurrenceString)
                        .font(.caption)
                        .foregroundStyle(Color.secondary.opacity(isCompletedForDisplay ? 0.7 : 1.0))
                        .strikethrough(isCompletedForDisplay, color: .secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
