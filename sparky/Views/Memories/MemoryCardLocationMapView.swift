//
//  MemoryCardLocationMapView.swift
//  sparky
//
//  Created by Codex on 13/10/25.
//

import SwiftUI

struct MemoryCardLocationMapView: View {
    let location: LocationConfig
    let isCompletedForDisplay: Bool

    private var locationName: String {
        if let name = location.name, !name.isEmpty {
            return name
        }
        return String(format: "%.4f, %.4f", location.latitude, location.longitude)
    }

    var body: some View {
        MemoryCardMetaBadge(
            systemImage: "location.fill",
            text: locationName,
            isCompleted: isCompletedForDisplay
        )
    }
}
