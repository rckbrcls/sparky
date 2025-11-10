import SwiftUI

struct SpaceDetailSubspacesSection: View {
    let childSpaces: [SpaceModel]
    let spaceService: SpaceService
    let memoryCountProvider: (SpaceModel) -> Int
    let parentLookup: (UUID) -> SpaceModel?

    private var listHeight: CGFloat {
        let rowHeight: CGFloat = 68
        let headerHeight: CGFloat = 48
        return (CGFloat(childSpaces.count) * rowHeight) + headerHeight
    }

    var body: some View {
        List {
            Section("Subspaces") {
                ForEach(childSpaces) { child in
                    NavigationLink(value: child) {
                        SpaceRowView(
                            space: child,
                            count: memoryCountProvider(child),
                            spaceService: spaceService,
                            parentLookup: parentLookup
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listRowSeparator(.hidden)
        .listSectionSeparator(.hidden)
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
        .frame(height: listHeight)
        .padding(.horizontal, -16)
    }
}
