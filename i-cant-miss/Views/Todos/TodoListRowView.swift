//
//  TodoListRowView.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import SwiftUI

struct TodoListRowView: View {
    let list: TodoListModel
    let onTogglePin: () -> Void

    private let accentColor = Color("AccentColor")

    var body: some View {
        HStack(spacing: 16) {
            progressView
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(list.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if list.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .rotationEffect(.degrees(45))
                            .foregroundStyle(accentColor)
                            .accessibilityHidden(true)
                    }
                }

                if let dueDateText = dueDateText {
                    Label(dueDateText, systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(dueDateTint)
                }

                Text(progressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button(action: onTogglePin) {
                Image(systemName: list.isPinned ? "pin.slash" : "pin")
                    .font(.callout)
                    .padding(8)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .tint(accentColor)
            .accessibilityLabel(list.isPinned ? "Unpin list" : "Pin list")
        }
        .padding(.vertical, 12)
    }

    private var progressView: some View {
        ZStack {
            Circle()
                .strokeBorder(.quaternary, lineWidth: 6)

            Circle()
                .trim(from: 0, to: min(list.completionRate, 1.0))
                .stroke(list.isCompleted ? .green : accentColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text(completionPercentageString)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var dueDateText: String? {
        guard let dueDate = list.dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: dueDate)
    }

    private var dueDateTint: Color {
        guard let dueDate = list.dueDate else { return .secondary }
        if dueDate < Date().addingTimeInterval(-86400) {
            return .red
        } else if dueDate < Date().addingTimeInterval(86400) {
            return .orange
        }
        return .secondary
    }

    private var progressText: String {
        let completed = list.items.filter(\.isCompleted).count
        let total = list.items.count
        let pending = list.items.filter { !$0.isCompleted }.count

        if total == 0 {
            return "No items yet"
        }

        if pending == 0 {
            return "All \(total) items completed"
        }

        return "\(completed) completed • \(pending) remaining"
    }

    private var completionPercentageString: String {
        guard list.items.count > 0 else { return "0%" }
        let percentage = Int(round(list.completionRate * 100))
        return "\(percentage)%"
    }
}

#Preview("Todo List Row", traits: .sizeThatFitsLayout) {
    let list = TodoListModel(
        id: UUID(),
        title: "Product launch checklist",
        notes: "Coordinate across design, marketing and engineering.",
        dueDate: Date().addingTimeInterval(86400),
        isPinned: true,
        isArchived: false,
        createdAt: Date(),
        updatedAt: Date(),
        userOrder: 0,
        items: [
            TodoItemModel(
                id: UUID(),
                title: "Finalize landing page copy",
                detail: "Route through legal for approval.",
                isCompleted: true,
                sortOrder: 0,
                createdAt: Date(),
                completedAt: Date()
            ),
            TodoItemModel(
                id: UUID(),
                title: "Schedule email campaign",
                detail: nil,
                isCompleted: false,
                sortOrder: 1,
                createdAt: Date(),
                completedAt: nil
            )
        ]
    )

    TodoListRowView(list: list, onTogglePin: {})
        .padding()
}
