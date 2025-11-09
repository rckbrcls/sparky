import SwiftUI

struct SpacePicker: View {
    @Binding var selection: UUID
    let spaces: [SpaceModel]

    var body: some View {
        Picker(selection: $selection) {
            ForEach(spaces) { space in
                Text(space.name).tag(space.id)
            }
        } label: {
            Label("Space", systemImage: "folder")
        }
        .pickerStyle(.menu)
    }
}
