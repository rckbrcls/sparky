//
//  TodoItemRowView.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import SwiftUI

struct TodoItemRowView: View {
    let item: TodoItemModel
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isCompleted ? .green : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.body)
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                        .strikethrough(item.isCompleted, color: .secondary)

                    if let detail = item.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }

                Spacer(minLength: 0)

                if let completedAt = item.completedAt {
                    Text(completedAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Todo Item Row", traits: .sizeThatFitsLayout) {
    VStack {
        TodoItemRowView(
            item: TodoItemModel(
                id: UUID(),
                title: "Review marketing copy",
                detail: "Confirm tone matches brand guidelines.",
                isCompleted: false,
                sortOrder: 0,
                createdAt: Date(),
                completedAt: nil
            ),
            onToggle: {}
        )

        TodoItemRowView(
            item: TodoItemModel(
                id: UUID(),
                title: "Confirm press assets",
                detail: nil,
                isCompleted: true,
                sortOrder: 1,
                createdAt: Date(),
                completedAt: Date()
            ),
            onToggle: {}
        )
    }
    .padding()
}
