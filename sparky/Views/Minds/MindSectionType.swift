//
//  MindSectionType.swift
//  sparky
//

import SwiftUI

enum MindSectionType: CaseIterable, Hashable {
    case minds
    case pinned
    case active
    case complete

    var title: String {
        switch self {
        case .minds:
            return "Minds"
        case .pinned:
            return "Pinned"
        case .active:
            return "Active"
        case .complete:
            return "Complete"
        }
    }

    var iconName: String {
        switch self {
        case .minds:
            return "brain.fill"
        case .pinned:
            return "pin.fill"
        case .active:
            return "bolt.fill"
        case .complete:
            return "checkmark.circle.fill"
        }
    }
}
