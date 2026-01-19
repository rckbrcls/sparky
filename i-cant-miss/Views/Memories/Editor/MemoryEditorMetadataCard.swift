//
//  MemoryEditorMetadataCard.swift
//  i-cant-miss
//
//  Created by Codex on 15/01/25.
//

import SwiftUI

struct MemoryEditorMetadataCard: View {
    let createdAt: Date
    let updatedAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Created")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("at")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text("Last updated")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(updatedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("at")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(updatedAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }
}

#Preview {
    MemoryEditorMetadataCard(
        createdAt: Date(),
        updatedAt: Date().addingTimeInterval(3600)
    )
    .padding()
}
