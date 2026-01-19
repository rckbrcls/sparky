//
//  MemoryCardSequentialItemView.swift
//  i-cant-miss
//
//  Created by Codex on 02/01/26.
//

import SwiftUI

struct MemoryCardSequentialItemView: View {
    let memory: MemoryModel
    let isCompletedForDisplay: Bool
    
    private var spaceIcon: String {
        memory.space?.iconName ?? "square.grid.2x2.fill"
    }
    
    private var spaceColor: Color {
        memory.space?.colorHex.flatMap { Color(hex: $0) } ?? .gray
    }
    
    private var title: String {
        let trimmed = memory.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: spaceIcon)
                .foregroundStyle(spaceColor)
                .frame(width: 16, height: 16)
                .glassEffect(.regular.tint(spaceColor.opacity(0.15)))
            
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(isCompletedForDisplay ? .secondary : .primary)
                .strikethrough(isCompletedForDisplay, color: .secondary)
                .lineLimit(1)
            
            Spacer(minLength: 4)
            
            if isCompletedForDisplay {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(width: 140)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color("ElementBackground"))
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color("ElementBorder"), lineWidth: 2)
        )
    }
}

#Preview {
    let memory = MemoryModel(
        id: UUID(),
        title: "Sample Memory",
        body: "This is a sample memory body.",
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
    MemoryCardSequentialItemView(memory: memory, isCompletedForDisplay: false)
        .padding()
}
