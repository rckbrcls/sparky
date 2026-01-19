//
//  MemoryCardSequentialView.swift
//  i-cant-miss
//
//  Created by Codex on 02/01/26.
//

import SwiftUI

struct MemoryCardSequentialView: View {
    let memories: [MemoryModel]
    var displayDate: Date?
    
    private func isCompletedForDisplay(memory: MemoryModel) -> Bool {
        // For recurring memories with a displayDate, use date-specific completion
        if let date = displayDate, memory.hasRecurringTriggers {
            return memory.isCompleted(for: date)
        }
        // Otherwise, use the global status
        return memory.isCompleted
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Scroll horizontal com cards das memórias
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(memories.enumerated()), id: \.element.id) { index, memory in
                        MemoryCardSequentialItemView(
                            memory: memory,
                            isCompletedForDisplay: isCompletedForDisplay(memory: memory)
                        )
                        
                        // Seta entre cards (não mostrar após o último)
                        if index < memories.count - 1 {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .frame(width: 12)
                        }
                    }
                }
                .padding(6)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("ElementBorder"), lineWidth: 2)
            )
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 8)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 12,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 12
            )
            .fill(Color("ElementBackground"))
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 12,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 12
            )
            .stroke(Color("ElementBorder"), lineWidth: 2)
        )
    }
}

#Preview {
    let memory1 = MemoryModel(
        id: UUID(),
        title: "First Step",
        body: nil,
        createdAt: Date(),
        updatedAt: Date(),
        status: .active,
        isPinned: false,
        dueDate: nil,
        space: nil,
        triggers: [],
        checkItems: [],
        autoCompleteOnChecklistCompletion: false,
        note: nil,
        photoAttachmentIDs: [],
        linkAttachmentIDs: [],
        audioAttachmentIDs: [],
        fileAttachmentIDs: [],
        attachments: [],
        completedDates: []
    )
    let memory2 = MemoryModel(
        id: UUID(),
        title: "Second Step",
        body: nil,
        createdAt: Date(),
        updatedAt: Date(),
        status: .completed,
        isPinned: false,
        dueDate: nil,
        space: nil,
        triggers: [],
        checkItems: [],
        autoCompleteOnChecklistCompletion: false,
        note: nil,
        photoAttachmentIDs: [],
        linkAttachmentIDs: [],
        audioAttachmentIDs: [],
        fileAttachmentIDs: [],
        attachments: [],
        completedDates: []
    )
    MemoryCardSequentialView(
        memories: [memory1, memory2]
    )
    .padding()
}
