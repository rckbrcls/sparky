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
        HStack(spacing: 12) {
            Image(systemName: "location.fill")
                .font(.caption)
                .foregroundStyle(isCompletedForDisplay ? .secondary : .primary)
                .frame(width: 20)

            Text(locationName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(isCompletedForDisplay ? .secondary : .primary)
                .strikethrough(isCompletedForDisplay, color: .secondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(location.event.displayName)
                .font(.caption)
                .foregroundStyle(Color.secondary.opacity(isCompletedForDisplay ? 0.7 : 1.0))
                .strikethrough(isCompletedForDisplay, color: .secondary)
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 10)
    }
}
