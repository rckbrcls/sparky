//
//  MindGridItemView.swift
//  i-cant-miss
//

import SwiftUI

struct MindGridItemView: View {
    let mind: MindModel
    let count: Int
    let mindService: MindService?
    let spaceService: SpaceService?

    @State private var showingDeleteConfirmation = false

    init(
        mind: MindModel,
        count: Int,
        mindService: MindService? = nil,
        spaceService: SpaceService? = nil,
        onEdit: ((MindModel) -> Void)? = nil
    ) {
        self.mind = mind
        self.count = count
        self.mindService = mindService
        self.spaceService = spaceService
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

                Text("\(count)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
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
                Text("This mind contains \(count) space\(count == 1 ? "" : "s"). Spaces will be moved to \"No Mind\".")
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
            count: 5
        )
        MindGridItemView(
            mind: MindModel(id: UUID(), name: "Personal"),
            count: 3
        )
    }
    .padding()
}
