import SwiftUI

struct MemorySortMenu: View {
    @Binding var sortStrategy: MemoryService.SortStrategy

    var body: some View {
        Menu {
            Section("Data de Criação") {
                Button {
                    sortStrategy = .createdAtAscending
                } label: {
                    HStack {
                        Text("Mais Antiga Primeiro")
                        if sortStrategy == .createdAtAscending {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Button {
                    sortStrategy = .createdAtDescending
                } label: {
                    HStack {
                        Text("Mais Recente Primeiro")
                        if sortStrategy == .createdAtDescending {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Section("Data de Edição") {
                Button {
                    sortStrategy = .updatedAtAscending
                } label: {
                    HStack {
                        Text("Mais Antiga Primeiro")
                        if sortStrategy == .updatedAtAscending {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Button {
                    sortStrategy = .updatedAtDescending
                } label: {
                    HStack {
                        Text("Mais Recente Primeiro")
                        if sortStrategy == .updatedAtDescending {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                Text("Ordenar")
            }
            .font(.caption2.bold())
            .foregroundStyle(.primary)
            .padding(.horizontal)
            .frame(height: 32)
            .contentShape(Capsule())
            .background(
                Capsule()
                    .fill(Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(Color("ElementBorder"), lineWidth: 2)
            )
        }
        .accessibilityLabel("Ordenar memórias")
    }
}
