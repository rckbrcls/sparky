//
//  CalendarWeekDivider.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct CalendarWeekDivider: View {
    let startDate: Date
    let endDate: Date

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter
    }

    var body: some View {
        HStack {
            Text("\(dateFormatter.string(from: startDate).uppercased()) - \(dateFormatter.string(from: endDate).uppercased())")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

#Preview {
    let calendar = Calendar.current
    let start = calendar.date(byAdding: .day, value: -3, to: Date()) ?? Date()
    let end = calendar.date(byAdding: .day, value: 3, to: Date()) ?? Date()

    return CalendarWeekDivider(startDate: start, endDate: end)
}
