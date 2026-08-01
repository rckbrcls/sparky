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

    private var completedCount: Int {
        checkItems.filter(\.isCompleted).count
    }

    private var totalCount: Int {
        checkItems.count
    }

    var body: some View {
        VStack(spacing: 0) {

            if isExpanded {
                Spacer().frame(height: 4)

                ForEach(checkItems) { item in
                    HStack(alignment: .center, spacing: 12) {
                        Text(item.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(item.isCompleted ? .secondary : .primary)
                            .strikethrough(item.isCompleted, color: .secondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            PlatformHaptics.impactMedium()
                            onToggleItem(item.id)
                        } label: {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(item.isCompleted ? Color.accentColor : .secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    Divider()
                }
                .padding(.bottom, 6)
            }

            // Collapsed header: [short bar] [count] ........ [chevron]
            Button {
                isExpanded.toggle()
                PlatformHaptics.impactMedium()
            } label: {
                HStack(spacing: 8) {
                    // Compact progress bar (not full card width)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.22))
                        if totalCount > 0, completedCount > 0 {
                            Capsule()
                                .fill(Color.secondary.opacity(0.55))
                                .frame(
                                    width: 56 * CGFloat(completedCount) / CGFloat(totalCount)
                                )
                        }
                    }
                    .frame(width: 56, height: 3)

                    Text("\(completedCount)/\(totalCount)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            


        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}
