//
//  MemoryCardSequentialView.swift
//  i-cant-miss
//
//  Created by Codex on 02/01/26.
//

import SwiftUI

struct MemoryCardSequentialView: View {
    let memories: [MemoryModel]
    let startDate: Date?
    var displayDate: Date?
    
    private func isCompletedForDisplay(memory: MemoryModel) -> Bool {
        // For recurring memories with a displayDate, use date-specific completion
        if let date = displayDate, memory.hasRecurringTriggers {
            return memory.isCompleted(for: date)
        }
        // Otherwise, use the global status
        return memory.isCompleted
    }
    
    private func startDateString(for date: Date?) -> String {
        guard let date = date else { return "No start date" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Data de início à esquerda
            VStack(alignment: .leading, spacing: 4) {
                Text("Start Date")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                Text(startDateString(for: startDate))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .padding(.leading, 12)
            .frame(width: 90, alignment: .leading)
            
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
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color("ElementBackground").opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("ElementBorder"), lineWidth: 2)
            )
            .padding(.horizontal, 8)
        }
        .frame(height: 120)
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
        memories: [memory1, memory2],
        startDate: Date()
    )
    .padding()
}
