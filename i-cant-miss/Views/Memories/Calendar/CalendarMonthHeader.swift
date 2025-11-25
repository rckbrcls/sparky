//
//  CalendarMonthHeader.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct CalendarMonthHeader: View {
    @Binding var selectedDate: Date
    @Binding var searchText: String

    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(monthFormatter.string(from: selectedDate))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Spacer()

                if !isToday {
                    Button {
                        withAnimation {
                            selectedDate = Date()
                        }
                    } label: {
                        Text("Today")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accent.opacity(0.2))
                            .foregroundStyle(.accent)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }
}

#Preview {
    CalendarMonthHeader(
        selectedDate: .constant(Date()),
        searchText: .constant("")
    )
}
