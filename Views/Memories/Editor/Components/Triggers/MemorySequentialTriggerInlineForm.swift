import SwiftUI

struct MemorySequentialTriggerInlineForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showSheet: Bool
    let memoryLookup: [UUID: MemoryModel]

    private var configuration: MemoryTriggerModel.TriggerSequential? {
        viewModel.sequentialTrigger?.sequential
    }

    var body: some View {
        if hasConfiguration {
            Button {
                showSheet = true
            } label: {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "arrowshape.turn.up.right.circle")
                        .font(.caption.bold())
                    Text(summaryText)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.glass)
            .swipeActions {
                Button(role: .destructive) {
                    viewModel.removeSequentialTrigger()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            Button {
                showSheet = true
            } label: {
                Label("Sequence", systemImage: "arrowshape.turn.up.right.circle.badge.clockwise")
                    .foregroundStyle(.accent)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.glass)
        }
    }

    private var hasConfiguration: Bool {
        guard let configuration else { return false }
        return configuration.previousMemoryID != nil || configuration.nextMemoryID != nil
    }

    private var summaryText: String {
        guard let configuration else { return "Sequential trigger" }
        let previous = configuration.previousMemoryID.flatMap { name(for: $0) }
        let next = configuration.nextMemoryID.flatMap { name(for: $0) }

        switch (previous, next) {
        case let (prev?, next?):
            return "\(prev) → \(next)"
        case let (prev?, nil):
            return "After \(prev)"
        case let (nil, next?):
            return "Activates \(next)"
        default:
            return "Sequential trigger"
        }
    }

    private func name(for id: UUID) -> String {
        if let title = memoryLookup[id]?.title, !title.isEmpty {
            return title
        }
        return String(id.uuidString.prefix(6)) + "…"
    }
}
