import SwiftUI

struct SequentialTriggerInlineForm: View {
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
        return !configuration.previousMemoryIDs.isEmpty || !configuration.nextMemoryIDs.isEmpty
    }

    private var summaryText: String {
        guard let configuration else { return "Sequential trigger" }

        let prevCount = configuration.previousMemoryIDs.count
        let nextCount = configuration.nextMemoryIDs.count

        if prevCount > 0 && nextCount > 0 {
            if prevCount == 1 && nextCount == 1 {
                let prev = name(for: configuration.previousMemoryIDs[0])
                let next = name(for: configuration.nextMemoryIDs[0])
                return "\(prev) → \(next)"
            }
            return "\(prevCount) previous → \(nextCount) next"
        } else if prevCount > 0 {
            if prevCount == 1 {
                return "After \(name(for: configuration.previousMemoryIDs[0]))"
            }
            return "After \(prevCount) memories"
        } else if nextCount > 0 {
            if nextCount == 1 {
                return "Activates \(name(for: configuration.nextMemoryIDs[0]))"
            }
            return "Activates \(nextCount) memories"
        }

        return "Sequential trigger"
    }

    private func name(for id: UUID) -> String {
        if let title = memoryLookup[id]?.title, !title.isEmpty {
            return title
        }
        return String(id.uuidString.prefix(6)) + "…"
    }
}
