//
//  MemoryCardChecklistView.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import SwiftUI

struct MemoryCardChecklistView: View {
    let checkItems: [CheckItemModel]
    let onToggleItem: (UUID) -> Void
    let isCompletedForDisplay: Bool
    
    @State private var isExpanded = false
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    private var completedCount: Int {
        checkItems.filter(\.isCompleted).count
    }
    
    private var totalCount: Int {
        checkItems.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Collapsed header
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
                feedbackGenerator.impactOccurred()
            } label: {
                HStack(spacing: 12) {
                    // Chevron icon
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    // Progress text
                    Text("\(completedCount)/\(totalCount)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                            
                            if totalCount > 0 {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.accentColor)
                                    .frame(width: geometry.size.width * CGFloat(completedCount) / CGFloat(totalCount))
                            }
                        }
                    }
                    .frame(height: 4)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Expanded content
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(checkItems) { item in
                        Button {
                            feedbackGenerator.impactOccurred()
                            onToggleItem(item.id)
                        } label: {
                            HStack(alignment: .center, spacing: 12) {
                                Text(item.title)
                                    .font(.callout)
                                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                                    .strikethrough(item.isCompleted, color: .secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.body)
                                    .foregroundStyle(item.isCompleted ? .green : .secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        if item.id != checkItems.last?.id {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
                .padding(.bottom, 12)
                .transition(.opacity)
            }
        }
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 12,
                bottomTrailingRadius: 12,
                topTrailingRadius: 0
            )
            .fill(Color("ElementBackground").opacity(0.5))
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 12,
                bottomTrailingRadius: 12,
                topTrailingRadius: 0
            )
            .stroke(Color("ElementBorder"), lineWidth: 2)
        )
    }
}
