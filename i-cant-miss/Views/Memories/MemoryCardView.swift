//
//  MemoryRowView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct MemoryCardView: View {
    let memory: MemoryModel
    @EnvironmentObject private var environment: AppEnvironment

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
        let trimmed = memory.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
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

    private var sequentialSummary: String? {
        guard let sequential = memory.triggers.first(where: { $0.type == .sequential })?.sequential else {
            return nil
        }

        var parts: [String] = []
        if let previous = sequential.previousMemoryID {
            parts.append("After \(sequentialLabel(for: previous))")
        }
        if let next = sequential.nextMemoryID {
            parts.append("Then \(sequentialLabel(for: next))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private var statusBadge: (text: String, systemImage: String, color: Color)? {
        switch memory.status {
        case .active:
            return nil
        case .completed:
            return ("Completed", "checkmark.circle.fill", .green)
        }
    }

    private var spaceAccent: Color {
        if let hex = memory.space?.colorHex,
           let color = Color(hex: hex) {
            return color
        }
        return .accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let hasMetaIndicators = memory.priority != nil || statusBadge != nil
            let hasSpaceBadge = memory.space != nil

            if hasSpaceBadge || hasMetaIndicators {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let space = memory.space {
                        HStack(spacing: 8) {
                            if let icon = space.iconName {
                                Image(systemName: icon)
                                    .font(.caption)
                                    .foregroundStyle(spaceAccent)
                            }
                            Text(space.name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(spaceAccent)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .glassEffect(in: .rect(cornerRadius: 8.0))
                        .glassEffect(.regular.tint(spaceAccent.opacity(0.15)))
                    }

                    if hasSpaceBadge && hasMetaIndicators {
                        Spacer()
                    }

                    if hasMetaIndicators {
                        HStack(spacing: 12) {
                            if let priority = memory.priority {
                                Image(systemName: priority.iconName)
                                    .font(.subheadline)
                                    .foregroundStyle(priorityColor(for: priority))
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
                    }
                }
            }

            VStack (alignment: .leading, spacing: 6){
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)


                if let bodyPreview {
                    Text(bodyPreview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

            }
            
            if sequentialSummary != nil || nextTriggerText != nil || dueDateText != nil || checklistProgressText != nil {
                Divider()
                
                HStack(spacing: 12) {
                    if let sequentialSummary {
                        Label(sequentialSummary, systemImage: "arrowshape.turn.up.right.circle")
                            .font(.caption)
                            .lineLimit(1)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .glassEffect()
                    }
                    
                    if let nextTriggerText {
                        Label(nextTriggerText, systemImage: "alarm")
                            .font(.caption)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .glassEffect()
                    }
                    
                    if let dueDateText {
                        Label(dueDateText, systemImage: "calendar")
                            .font(.caption)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .glassEffect()
                    }
                    
                    if let checklistProgressText {
                        Label(checklistProgressText, systemImage: "checklist")
                            .font(.caption)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .glassEffect()
                    }
                }
            }            
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 24))
        .contentShape(Rectangle())
    }

    private func priorityColor(for priority: MemoryPriority) -> Color {
        switch priority {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }

    private func sequentialLabel(for id: UUID) -> String {
        if let memory = environment.memoryService.memory(id: id) {
            let trimmed = memory.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return String(id.uuidString.prefix(6)) + "…"
    }
}
#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return ContentView(environment: environment)
        .environmentObject(environment)
}
