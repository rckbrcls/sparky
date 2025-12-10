//
//  MemoryStatus.swift
//  i-cant-miss
//

import Foundation

enum MemoryStatus: String, CaseIterable, Identifiable, Codable {
    case active
    case completed

    var id: String { rawValue }
}
