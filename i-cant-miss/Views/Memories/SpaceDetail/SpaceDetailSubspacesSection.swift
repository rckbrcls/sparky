import SwiftUI

struct SpaceDetailSubspacesSection: View {
    let childSpaces: [SpaceModel]
    let spaceService: SpaceService
    let memoryService: MemoryService?
    let memoryCountProvider: (SpaceModel) -> Int

    var body: some View {
        if childSpaces.isEmpty {
            EmptyView()
        } else {
            Section {
                ForEach(childSpaces) { child in
                    NavigationLink(value: child) {
                        SpaceRowView(
                            space: child,
                            count: memoryCountProvider(child),
                            spaceService: spaceService,
                            memoryService: memoryService
                        )
                    }
                    .listRowInsets(.init(top: 12, leading: 20, bottom: 12, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } header: {
                Text("Subspaces")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)
            }
            .listSectionSeparator(.hidden)
            .textCase(nil)
        }
    }
}
