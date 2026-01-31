//
//  SequentialMemoryCard.swift
//  sparky
//
//  Created by Codex on 02/01/26.
//

import SwiftUI

struct SequentialMemoryCard: View {
    let memory: Memory
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Lobe Icon
            let lobeIcon = memory.lobe?.iconName ?? "brain.fill"
            let lobeColor = memory.lobe?.colorHex.flatMap { Color(hex: $0) } ?? .gray

            Image(systemName: lobeIcon)
                .foregroundStyle(lobeColor)
                .frame(width: 32, height: 32)
                .glassEffect(.regular.tint(lobeColor.opacity(0.15)))

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(memory.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(memory.isCompleted ? .secondary : .primary)
                    .strikethrough(memory.isCompleted, color: .secondary)
                    .lineLimit(1)

                if let lobeName = memory.lobe?.name {
                    Text(lobeName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .font(.caption)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("ElementBackground"))
        )
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

#Preview {
    let memory = Memory(
        id: UUID(),
        title: "Sample Memory",
        body: "This is a sample memory body.",
        statusRaw: MemoryStatus.active.rawValue,
        isPinned: false,
        dueDate: nil,
        createdAt: Date(),
        updatedAt: Date(),
        userOrder: 0,
        autoCompleteOnChecklistCompletion: false,
        space: nil
    )

    SequentialMemoryCard(memory: memory) {}
        .padding()
        .background(Color(.systemGroupedBackground))
}
