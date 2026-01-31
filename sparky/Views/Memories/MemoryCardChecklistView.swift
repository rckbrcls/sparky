//
//  MemoryCardChecklistView.swift
//  sparky
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

            if isExpanded {
                ForEach(checkItems) { item in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(item.isCompleted ? .secondary : .primary)
                                .strikethrough(item.isCompleted, color: .secondary)
                                .lineLimit(2)

                            if let detail = item.detail {
                                Text(detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .strikethrough(item.isCompleted, color: .secondary)
                                    .lineLimit(2)
                            }
                        }

                        Spacer()

                        Button {
                            feedbackGenerator.impactOccurred()
                            onToggleItem(item.id)
                        } label: {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(item.isCompleted ? Color.accentColor : .secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)

                    if item.id != checkItems.last?.id {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
                .padding(.bottom, 6)
            }

            // Collapsed header
            Button {
                isExpanded.toggle()
                feedbackGenerator.impactOccurred()
            } label: {
                HStack(spacing: 12) {
                    // Chevron icon
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))

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
                    .frame(maxWidth: 80, maxHeight: 4)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            


        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}
