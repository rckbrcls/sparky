//
//  CustomTabBar.swift
//  i-cant-miss
//
//  Created by Codex on 18/03/25.
//

import SwiftUI

struct CustomTabBar: View {
    struct Item: Identifiable {
        let title: String
        let icon: String
        let selection: TabRouter.Selection
        
        var id: TabRouter.Selection { selection }
    }
    
    let items: [Item]
    @Binding var selection: TabRouter.Selection
    var isTerminalActive: Bool
    var onTerminalTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(items) { item in
                tabButton(for: item)
            }
            
            terminalButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassEffect()
    }
    
    private func tabButton(for item: Item) -> some View {
        let isSelected = selection == item.selection
        
        return Button {
            guard selection != item.selection else { return }
            selection = item.selection
        } label: {
            VStack(spacing: 4) {
                Image(systemName: item.icon)
                    .font(.body.weight(.semibold))
                Text(item.title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
    
    private var terminalButton: some View {
        Button {
            onTerminalTap()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "apple.terminal")
                    .font(.headline.weight(.bold))
                Text("Terminal")
                    .font(.caption2.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(Color.white)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(terminalGradient)
                    .overlay {
                        if isTerminalActive {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        }
                    }
            )
            .shadow(color: Color.accentColor.opacity(0.35), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.2), value: isTerminalActive)
    }
    
    private var terminalGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.accentColor,
                Color.accentColor.opacity(0.85)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selection: TabRouter.Selection = .timeline
        @State private var isTerminalPresented = false
        
        var body: some View {
            VStack {
                Spacer()
                CustomTabBar(
                    items: [
                        .init(title: "Timeline", icon: "list.bullet.rectangle", selection: .timeline),
                        .init(title: "Spaces", icon: "square.grid.2x2", selection: .spaces),
                        .init(title: "Settings", icon: "gearshape", selection: .settings)
                    ],
                    selection: $selection,
                    isTerminalActive: isTerminalPresented,
                    onTerminalTap: { isTerminalPresented.toggle() }
                )
                .padding()
            }
            .background(Color.gray.opacity(0.1))
        }
    }
    
    return PreviewWrapper()
}
