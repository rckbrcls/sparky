//
//  MemoryRowView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct MemoryCardView: View {
    let memory: MemoryModel
    let transition: Namespace.ID?
    private let transitionSourceID: AnyHashable?

    init(
        memory: MemoryModel,
        transition: Namespace.ID?,
        transitionSourceID: AnyHashable? = nil
    ) {
        self.memory = memory
        self.transition = transition
        self.transitionSourceID = transitionSourceID
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private static let dueDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private var title: String {
        if let title = memory.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            return title
        }
        return "Untitled"
    }

    private var bodyPreview: String? {
        guard let body = memory.body?.trimmingCharacters(in: .whitespacesAndNewlines),
              !body.isEmpty else { return nil }
        return body
    }

    private var nextTriggerText: String? {
        guard let fireDate = memory.nextFireDate() else { return nil }
        let now = Date()
        return Self.relativeFormatter.localizedString(for: fireDate, relativeTo: now)
    }

    private var dueDateText: String? {
        guard let dueDate = memory.dueDate else { return nil }
        return Self.dueDateFormatter.string(from: dueDate)
    }

    private var checklistProgressText: String? {
        guard memory.hasChecklist else { return nil }
        let total = memory.checkItems.count
        guard total > 0 else { return nil }
        let completed = memory.checkItems.filter(\.isCompleted).count
        return "\(completed)/\(total)"
    }

    private var statusBadge: (text: String, systemImage: String, color: Color)? {
        switch memory.status {
        case .active:
            return nil
        case .completed:
            return ("Completed", "checkmark.circle.fill", .green)
        case .archived:
            return ("Archived", "archivebox.fill", .gray)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let priority = memory.priority {
                    Image(systemName: priority.iconName)
                        .font(.subheadline)
                        .foregroundStyle(priorityColor(for: priority))
                }

                if memory.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(45))
                        .accessibilityLabel("Pinned")
                }

                if let statusBadge {
                    Label {
                        Text(statusBadge.text)
                    } icon: {
                        Image(systemName: statusBadge.systemImage)
                    }
                    .font(.caption)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(statusBadge.color)
                    .padding(.leading, 4)
                }
            }

            if let bodyPreview {
                Text(bodyPreview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                if let nextTriggerText {
                    Label(nextTriggerText, systemImage: "alarm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let dueDateText {
                    Label(dueDateText, systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let checklistProgressText {
                    Label(checklistProgressText, systemImage: "checklist")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !memory.tags.isEmpty {
                Text(memory.tags.map(\.name).joined(separator: " • "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .optionalMatchedTransitionSource(
            id: transitionSourceID ?? AnyHashable(memory.id),
            in: transition
        )
    }

    private func priorityColor(for priority: MemoryPriority) -> Color {
        switch priority {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return ContentView(environment: environment)
}

private struct OptionalMatchedTransitionSource<ID: Hashable>: ViewModifier {
    let id: ID
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

private extension View {
    func optionalMatchedTransitionSource<ID: Hashable>(id: ID, in namespace: Namespace.ID?) -> some View {
        modifier(OptionalMatchedTransitionSource(id: id, namespace: namespace))
    }
}
