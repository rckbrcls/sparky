//
//  CalendarViewMode.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import Foundation

enum CalendarViewMode: Equatable {
    case year
    case month(Date) // Data do mês selecionado
    case day(Date)   // Data do dia selecionado

    var date: Date? {
        switch self {
        case .year:
            return nil
        case .month(let date), .day(let date):
            return date
        }
    }
}
