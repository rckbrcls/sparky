import SwiftUI

struct SpacePicker: View {
    @Binding var selection: UUID?
    let spaces: [SpaceModel]

    private var selectedSpaceName: String {
        guard let selection = selection else {
            return "No Space"
        }
        return spaces.first(where: { $0.id == selection })?.name ?? "No Space"
    }

    var body: some View {
        Picker(selection: $selection) {
            Text("No Space")
                .tag(UUID?.none)
            ForEach(spaces) { space in
                Text(space.name).tag(Optional(space.id))
            }
        } label: {
            Label(selectedSpaceName, systemImage: "folder")
        }
        .pickerStyle(.menu)
    }
}
