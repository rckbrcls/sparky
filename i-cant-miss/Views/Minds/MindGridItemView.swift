//
//  MindGridItemView.swift
//  i-cant-miss
//

import SwiftUI

struct MindGridItemView: View {
    let mind: MindModel
    let count: Int
    let activeCount: Int
    let mindService: MindService?
    let lobeService: LobeService?

    @State private var showingDeleteConfirmation = false

    init(
        mind: MindModel,
        count: Int,
        activeCount: Int = 0,
        mindService: MindService? = nil,
        lobeService: LobeService? = nil,
        onEdit: ((MindModel) -> Void)? = nil
    ) {
        self.mind = mind
        self.count = count
        self.activeCount = activeCount
        self.mindService = mindService
        self.lobeService = lobeService
        self.onEdit = onEdit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: mind.iconName ?? "brain.head.profile")
                    .foregroundStyle(mindColor)
                    .frame(width: 32, height: 32)
                    .glassEffect(.regular.tint(mindColor.opacity(0.15)))

                Spacer()

                if activeCount > 0 {
                    Text("\(activeCount)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .frame(height: 20)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(mindColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(darkerBorderColor(for: mindColor), lineWidth: 1)
                                )
                        )
                }
            }
            Text(mind.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 60)
        .cardStyle()
        .contextMenu {
            if canEditMind {
                Button {
                    onEdit?(mind)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }

            if canDeleteMind {
                Button(role: .destructive) {
                    Task { @MainActor in
                        showingDeleteConfirmation = true
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .alert("Delete Mind", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteMind()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if count > 0 {
                Text("This mind contains \(count) lobe\(count == 1 ? "" : "s"). Lobes will be moved to \"No Mind\".")
            } else {
                Text("Are you sure you want to delete this mind?")
            }
        }
    }

    var onEdit: ((MindModel) -> Void)?

    private var mindColor: Color {
        if let hex = mind.colorHex, let color = Color(hex: hex) {
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

    private var canEditMind: Bool {
        guard !mind.isAllMinds else { return false }
        return true
    }

    private var canDeleteMind: Bool {
        guard mindService != nil else { return false }
        guard !mind.isAllMinds else { return false }
        return !mind.isDefault
    }

    private func deleteMind() {
        guard let service = mindService else { return }
        guard !mind.isAllMinds,
              !mind.isDefault else { return }

        Task { @MainActor in
            do {
                try await service.deleteMind(mind)
            } catch {
                assertionFailure("Failed to delete mind: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    HStack {
        MindGridItemView(
            mind: MindModel(id: UUID(), name: "Work"),
            count: 5,
            activeCount: 12
        )
        MindGridItemView(
            mind: MindModel(id: UUID(), name: "Personal"),
            count: 3,
            activeCount: 8
        )
    }
    .padding()
}
