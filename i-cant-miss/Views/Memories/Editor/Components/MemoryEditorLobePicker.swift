import SwiftUI

struct LobePicker: View {
    @Binding var selection: UUID?
    let lobes: [LobeModel]

    private var selectedLobeName: String {
        guard let selection = selection else {
            return "No Lobe"
        }
        return lobes.first(where: { $0.id == selection })?.name ?? "No Lobe"
    }

    var body: some View {
        Picker(selection: $selection) {
            Text("No Lobe")
                .tag(UUID?.none)
            ForEach(lobes) { lobe in
                Text(lobe.name).tag(Optional(lobe.id))
            }
        } label: {
            Label(selectedLobeName, systemImage: "folder")
        }
        .pickerStyle(.menu)
    }
}
