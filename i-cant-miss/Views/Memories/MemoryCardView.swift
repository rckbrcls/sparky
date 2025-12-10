//
//  MemoryRowView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct MemoryCardView: View {
    let memoryID: UUID
    @ObservedObject var memoryService: MemoryService
    @EnvironmentObject private var environment: AppEnvironment

    init(memoryID: UUID, memoryService: MemoryService) {
        self.memoryID = memoryID
        self._memoryService = ObservedObject(wrappedValue: memoryService)
    }

    private var memory: MemoryModel? {
        memoryService.memory(id: memoryID)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .abbreviated
        return formatter
    }()



    private var title: String {
        guard let memory = memory else { return "Untitled" }
        let trimmed = memory.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    private var bodyPreview: String? {
        guard let memory = memory,
              let body = memory.body?.trimmingCharacters(in: .whitespacesAndNewlines),
              !body.isEmpty else { return nil }
        return body
    }

    private var scheduledDateText: String? {
        guard let memory = memory,
              let trigger = memory.triggers.first(where: { $0.type == .scheduled }),
              let fireDate = trigger.fireDate else { return nil }

        if trigger.weekdayMask != 0 {
            return fireDate.formatted(date: .omitted, time: .shortened)
        }
        return fireDate.formatted(date: .abbreviated, time: .shortened)
    }

    private var checklistProgressText: String? {
        guard let memory = memory,
              memory.hasChecklist else { return nil }
        let total = memory.checkItems.count
        guard total > 0 else { return nil }
        let completed = memory.checkItems.filter(\.isCompleted).count
        return "\(completed)/\(total)"
    }

    private var sequentialSummary: String? {
        guard let memory = memory,
              let sequential = memory.triggers.first(where: { $0.type == .sequential })?.sequential else {
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
        guard let memory = memory else { return nil }
        switch memory.status {
        case .active:
            return nil
        case .completed:
            return ("Completed", "checkmark.circle.fill", .green)
        }
    }

    private var spaceAccent: Color {
        guard let memory = memory,
              let hex = memory.space?.colorHex,
              let color = Color(hex: hex) else {
            return .accentColor
        }
        return color
    }

    var body: some View {
        if let memory = memory {
            memoryContent(memory: memory)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func memoryContent(memory: MemoryModel) -> some View {
        HStack(alignment: .center, spacing: 12) {
            let spaceIcon = memory.space?.iconName ?? "square.grid.2x2.fill"
            let spaceColor = memory.space?.colorHex.flatMap { Color(hex: $0) } ?? .gray

            Image(systemName: spaceIcon)
                .foregroundStyle(spaceColor)
                .frame(width: 36, height: 36)
                .glassEffect(.regular.tint(spaceColor.opacity(0.15)))

            VStack(alignment: .leading, spacing: 10) {
                let priorityToDisplay = memory.priority == .noPriority ? nil : memory.priority
                let hasMetaIndicators = priorityToDisplay != nil || statusBadge != nil

                if hasMetaIndicators {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Spacer()

                        HStack(spacing: 12) {
                            if let priority = priorityToDisplay {
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

            VStack (alignment: .leading, spacing: 6){
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)


                if let bodyPreview {
                    Text(bodyPreview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

            }

            if sequentialSummary != nil || scheduledDateText != nil || checklistProgressText != nil {
                HStack(spacing: 12) {
                    if let sequentialSummary {
                        Label(sequentialSummary, systemImage: "arrowshape.turn.up.right.circle")
                            .font(.caption)
                            .lineLimit(1)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                    }

                    if let scheduledDateText {
                        Label(scheduledDateText, systemImage: "calendar")
                            .font(.caption)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                    }

                    if let checklistProgressText {
                        Label(checklistProgressText, systemImage: "checklist")
                            .font(.caption)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                    }
                }
            }
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color(.secondarySystemBackground)))
        .contentShape(Rectangle())
    }

    private func priorityColor(for priority: MemoryPriority) -> Color {
        switch priority {
        case .noPriority: return .gray
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
    let sampleMemoryID = UUID()
    return MemoryCardView(memoryID: sampleMemoryID, memoryService: environment.memoryService)
        .environmentObject(environment)
        .padding()
}
