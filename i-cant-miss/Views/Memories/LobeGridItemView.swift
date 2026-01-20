//
//  LobeGridItemView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct LobeGridItemView: View {
    let lobe: LobeModel
    let count: Int
    let completedCount: Int
    let activeCount: Int
    let lobeService: LobeService?
    let memoryService: MemoryService?
    let mindService: MindService?
    let showOnlyRemaining: Bool

    @State private var showingDeleteConfirmation = false

    init(
        lobe: LobeModel,
        count: Int,
        completedCount: Int = 0,
        activeCount: Int = 0,
        lobeService: LobeService? = nil,
        memoryService: MemoryService? = nil,
        mindService: MindService? = nil,
        onEdit: ((LobeModel) -> Void)? = nil,
        showOnlyRemaining: Bool = false
    ) {
        self.lobe = lobe
        self.count = count
        self.completedCount = completedCount
        self.activeCount = activeCount
        self.lobeService = lobeService
        self.memoryService = memoryService
        self.mindService = mindService
        self.onEdit = onEdit
        self.showOnlyRemaining = showOnlyRemaining
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Lado esquerdo: ícone e título do lobe
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: lobe.iconName ?? "brain.fill")
                    .foregroundStyle(lobeColor)
                    .frame(width: 32, height: 32)
                    .glassEffect(.regular.tint(lobeColor.opacity(0.15)))
                
                Text(lobe.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Lado direito: active memories
            if activeCount > 0 {
                Text("\(activeCount)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .frame(height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(lobeColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(darkerBorderColor(for: lobeColor), lineWidth: 1)
                            )
                    )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 100)
        .cardStyle()
        .contextMenu {
            if canEditLobe {
                Button {
                    onEdit?(lobe)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }

            if let mindService = mindService, canEditLobe {
                Menu {
                    Button {
                        moveToMind(nil)
                    } label: {
                        HStack {
                            Image(systemName: "brain.head.profile")
                            Text("No Mind")
                            Spacer()
                            if lobe.mind == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    ForEach(mindService.minds.filter { !$0.isDefault }, id: \.id) { mind in
                        Button {
                            moveToMind(mind)
                        } label: {
                            HStack {
                                Image(systemName: mind.iconName ?? "brain.head.profile")
                                Text(mind.name)
                                Spacer()
                                if lobe.mind?.id == mind.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label(currentMindLabel, systemImage: "brain.head.profile")
                }
            }

            if canDeleteLobe {
                Button(role: .destructive) {
                    Task { @MainActor in
                        showingDeleteConfirmation = true
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .alert("Delete Lobe", isPresented: $showingDeleteConfirmation) {
            Button("Delete Lobe Only", role: .destructive) {
                deleteLobe(deleteMemories: false)
            }
            if count > 0 {
                Button("Delete Lobe and Memories", role: .destructive) {
                    deleteLobe(deleteMemories: true)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if count > 0 {
                Text("This lobe contains \(count) memory\(count == 1 ? "" : "ies"). Do you want to delete the lobe only (memories will be moved to \"No Lobe\") or delete the lobe and all its memories?")
            } else {
                Text("Are you sure you want to delete this lobe?")
            }
        }
    }

    /// Optional closure called when user taps edit swipe action
    var onEdit: ((LobeModel) -> Void)?

    private var lobeColor: Color {
        if let hex = lobe.colorHex, let color = Color(hex: hex) {
            return color
        }
        return .gray
    }

    private func darkerBorderColor(for color: Color) -> Color {
        // Cria uma versão mais escura da cor para a borda
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        if uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            // Reduz o brightness em 30% para criar uma borda mais escura
            return Color(hue: hue, saturation: saturation, brightness: max(0, brightness * 0.7), opacity: alpha)
        }
        
        // Fallback: usar a cor com opacity reduzida
        return color.opacity(0.6)
    }

    private var canEditLobe: Bool {
        guard !lobe.isAllLobes else { return false }
        guard !lobe.isAllLobeForMind else { return false }
        return true
    }

    private var canDeleteLobe: Bool {
        guard lobeService != nil else { return false }
        guard !lobe.isAllLobes else { return false }
        guard !lobe.isAllLobeForMind else { return false }
        return !lobe.isDefault
    }

    private var currentMindLabel: String {
        if let mind = lobe.mind {
            return mind.name
        } else {
            return "None"
        }
    }

    private var displayCount: String {
        if showOnlyRemaining {
            let remaining = count - completedCount
            return "\(remaining)"
        } else {
            return "\(completedCount)/\(count)"
        }
    }

    private func deleteLobe(deleteMemories: Bool) {
        guard let service = lobeService else { return }
        guard !lobe.isAllLobes,
              !lobe.isAllLobeForMind,
              !lobe.isDefault else { return }

        Task { @MainActor in
            do {
                try await service.deleteLobe(lobe, deleteMemories: deleteMemories, memoryService: memoryService)
            } catch {
                assertionFailure("Failed to delete lobe: \(error.localizedDescription)")
            }
        }
    }

    private func moveToMind(_ mind: MindModel?) {
        guard let service = lobeService else { return }
        guard !lobe.isAllLobes else { return }
        guard !lobe.isAllLobeForMind else { return }

        Task { @MainActor in
            do {
                var updatedLobe = lobe
                updatedLobe.mind = mind
                _ = try await service.updateLobe(updatedLobe)
                _ = await service.refresh(force: true)
            } catch {
                assertionFailure("Failed to move lobe to mind: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    HStack {
        LobeGridItemView(
            lobe: LobeModel(id: UUID(), name: "Inbox"),
            count: 12,
            activeCount: 8
        )
        LobeGridItemView(
            lobe: LobeModel(id: UUID(), name: "Work"),
            count: 5,
            completedCount: 2,
            activeCount: 3
        )
    }
    .padding()
}
