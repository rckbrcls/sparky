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
        return configuration != nil
    }

    private var summaryText: String {
        guard let configuration else { return "Sequential trigger" }
        return "Sequence Step \(configuration.stepIndex + 1)"
    }

    private func name(for id: UUID) -> String {
        if let title = memoryLookup[id]?.title, !title.isEmpty {
            return title
        }
        return String(id.uuidString.prefix(6)) + "…"
    }
}
