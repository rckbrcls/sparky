//
//  CalendarDayHeader.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct CalendarDayHeader: View {
    let date: Date

    private var weekdayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        HStack(spacing: 12) {
            if isToday {
                Text(dayFormatter.string(from: date))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text(dayFormatter.string(from: date))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }

            Text(weekdayFormatter.string(from: date).uppercased())
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

#Preview {
    VStack {
        CalendarDayHeader(date: Date())
        CalendarDayHeader(date: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
    }
}
