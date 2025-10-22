//
//  MemoryDetailPlaceholder.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct MemoryDetailPlaceholder: View {
    let memory: MemoryModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let bodyText = memory.body?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !bodyText.isEmpty {
                    Section("Notes") {
                        Text(bodyText)
                            .font(.body)
                    }
                }

                Section("Details") {
                    Label(memory.status.rawValue.capitalized, systemImage: statusIcon)

                    if let dueDate = memory.dueDate {
                        Label(dueDate.formatted(date: .complete, time: .shortened), systemImage: "calendar")
                    }

                    if let nextTrigger = memory.nextFireDate() {
                        Label(nextTrigger.formatted(date: .abbreviated, time: .shortened), systemImage: "alarm")
                    }

                    if !memory.tags.isEmpty {
                        Label(memory.tags.map(\.name).joined(separator: ", "), systemImage: "tag")
                    }
                }

                if memory.hasChecklist {
                    Section("Checklist") {
                        ForEach(memory.checkItems) { item in
                            HStack {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isCompleted ? .green : .secondary)
                                VStack(alignment: .leading) {
                                    Text(item.title)
                                    if let detail = item.detail, !detail.isEmpty {
                                        Text(detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(memory.title ?? "Memory")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var statusIcon: String {
        switch memory.status {
        case .active: return "circle"
        case .completed: return "checkmark.circle.fill"
        case .archived: return "archivebox.fill"
        }
    }
}

#Preview {
    let space = SpaceModel.inbox
    let memory = MemoryModel(
        id: UUID(),
        title: "Sample Memory",
        body: "This is a placeholder preview for the unified memory.",
        createdAt: Date(),
        updatedAt: Date(),
        status: .active,
        isPinned: false,
        priority: .medium,
        dueDate: Date().addingTimeInterval(3600),
        space: space,
        tags: [],
        triggers: [],
        checkItems: [],
        snoozeCount: 0,
        lastCompletionDate: nil,
        metadata: .init()
    )
    return MemoryDetailPlaceholder(memory: memory)
}
