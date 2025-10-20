//
//  String+Optional.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation

extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
