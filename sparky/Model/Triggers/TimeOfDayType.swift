//
//  TimeOfDayType.swift
//  sparky
//
//  Time of day type for schedule configuration.
//

import Foundation

enum TimeOfDayType: String, CaseIterable, Identifiable {
    case specificTime = "Specific Time"
    case allDay = "All Day"

    var id: String { rawValue }
}
