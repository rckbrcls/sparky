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

    // Context menu action callbacks (optional - if nil, context menu is disabled)
    var onTogglePin: (() -> Void)?
    var onToggleCompletion: (() -> Void)?
    var onDelete: (() -> Void)?
    var onMoveToSpace: ((UUID?) -> Void)?
    var onUpdateStatus: ((MemoryStatus) -> Void)?

    private var isContextMenuEnabled: Bool {
        onTogglePin != nil || onToggleCompletion != nil || onDelete != nil || onMoveToSpace != nil || onUpdateStatus != nil
    }

    init(
        memoryID: UUID,
        memoryService: MemoryService,
        onTogglePin: (() -> Void)? = nil,
        onToggleCompletion: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onMoveToSpace: ((UUID?) -> Void)? = nil,
        onUpdateStatus: ((MemoryStatus) -> Void)? = nil
    ) {
        self.memoryID = memoryID
        self._memoryService = ObservedObject(wrappedValue: memoryService)
        self.onTogglePin = onTogglePin
        self.onToggleCompletion = onToggleCompletion
        self.onDelete = onDelete
        self.onMoveToSpace = onMoveToSpace
        self.onUpdateStatus = onUpdateStatus
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

        return fireDate.formatted(date: .omitted, time: .shortened)
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
        return "Step \(sequential.stepIndex + 1)"
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
                .frame(width: 32, height: 32)
                .glassEffect(.regular.tint(spaceColor.opacity(0.15)))

            VStack(alignment: .leading, spacing: 6) {
                VStack (alignment: .leading, spacing: 6){
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(memory.isCompleted ? .secondary : .primary)
                        .strikethrough(memory.isCompleted, color: .secondary)


                    if let bodyPreview {
                        Text(bodyPreview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .strikethrough(memory.isCompleted, color: .secondary)
                    }

                }

                if sequentialSummary != nil || scheduledDateText != nil || checklistProgressText != nil {
                    HStack(spacing: 12) {
                        if let sequentialSummary {
                            HStack(spacing: 4) {
                                Image(systemName: "arrowshape.turn.up.right.circle")
                                Text(sequentialSummary)
                            }
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                        }

                        if let scheduledDateText {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                Text(scheduledDateText)
                            }
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                        }

                        if let checklistProgressText {
                            HStack(spacing: 4) {
                                Image(systemName: "checklist")
                                Text(checklistProgressText)
                            }
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                        }
                    }
                }
            }

            Spacer()

            // Completion check circle button
            if let onToggleCompletion = onToggleCompletion {
                Button {
                    onToggleCompletion()
                } label: {
                    Image(systemName: memory.status == .completed ? "checkmark.circle.fill" : "circle")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .contextMenu {
            if isContextMenuEnabled {
                if let onTogglePin = onTogglePin {
                    Button {
                        onTogglePin()
                    } label: {
                        Label(memory.isPinned ? "Unpin" : "Pin",
                              systemImage: memory.isPinned ? "pin.slash.fill" : "pin.fill")
                    }
                }


                if let onMoveToSpace = onMoveToSpace {
                    Menu {
                        Button {
                            onMoveToSpace(nil)
                        } label: {
                            Label("No Space", systemImage: "tray")
                        }

                        ForEach(environment.spaceService.spaces.filter { $0.id != SpaceModel.allSpacesIdentifier }, id: \.id) { space in
                            Button {
                                onMoveToSpace(space.id)
                            } label: {
                                Label(space.name, systemImage: space.iconName ?? "folder")
                            }
                        }
                    } label: {
                        Label("Move to Space", systemImage: "folder")
                    }
                }

                if let onUpdateStatus = onUpdateStatus {
                    Menu {
                        ForEach(MemoryStatus.allCases) { status in
                            Button {
                                onUpdateStatus(status)
                            } label: {
                                Label(status.rawValue.capitalized, systemImage: status == .active ? "play.circle" : "checkmark.circle")
                            }
                        }
                    } label: {
                        Label("Status", systemImage: "circle.circle")
                    }
                }

                if let onDelete = onDelete {
                    Divider()

                    Button {
                        Task {
                            try? await memoryService.duplicateMemory(memoryID: memoryID)
                        }
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
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
