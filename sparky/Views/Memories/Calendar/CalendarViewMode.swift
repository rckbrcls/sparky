//
//  CalendarViewMode.swift
//  sparky
//
//  Created by Codex on 09/03/24.
//

import Foundation

enum CalendarViewMode: Equatable {
    case month(Date) // Data do mês selecionado
    case day(Date)   // Data do dia selecionado

    var date: Date? {
        switch self {
        case .month(let date), .day(let date):
            return date
        }
    }
}






